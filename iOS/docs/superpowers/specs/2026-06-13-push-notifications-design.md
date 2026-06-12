# System-wide Push Notifications — Design

**Status:** Draft, pending review
**Date:** 2026-06-13
**Scope:** iOS client + Supabase backend (Postgres + Edge Functions + APNs)
**Out of scope:** Android (Flutter) and Web push; localization of push titles; quiet hours; review/photo events.

## 1. Problem

Today the KajHobe iOS app only delivers notifications while it is in the foreground (in-app badge + `UNUserNotificationCenter` driven by real-time Supabase channels). When the app is closed, the user gets nothing — no Lock Screen banner, no badge, no alert sound. This is unacceptable for a chat/marketplace app where missed messages cost deals.

The iOS client already has the skeleton (`PushNotificationManager.swift`, APNs entitlement, `aps-environment`), but the backend is missing: the `send-push-notification` Supabase Edge Function is called from iOS but does not exist, the `device_token` / `push_enabled` columns are not in the schema, and `UIApplication.didRegisterForRemoteNotifications` is never wired up — so no token is ever delivered to the OS callback. Push is currently a black hole.

## 2. Goals

- System-wide push notifications on iOS for: new messages, new interest requests, new offers, completion requests.
- Per-category user preferences (Settings screen).
- Per-conversation mute.
- DB-driven trigger: every business write that should produce a push does so automatically via a Postgres trigger. iOS does not call the push function directly.
- Master switch (`profiles.push_enabled`) so users can disable all push without uninstalling.
- Idempotent: re-installs, re-logins, foreground/background churn do not duplicate or lose state.
- Backwards compatible: existing in-app notification behavior is preserved.

## 3. Non-Goals

- Android (FCM) and Web push.
- Localized push titles (English only in v1).
- Quiet hours / Do Not Disturb (delegated to iOS Focus modes).
- Critical alerts / time-sensitive categories (requires Apple entitlement approval; `aps-environment` entitlement file is already permissive for a future upgrade).
- Push for review / photo events.
- Interactive Accept/Decline buttons directly in the push notification (v1 is tap-to-open only).
- Analytics on delivery beyond a `push_log` debug table.

## 4. Architecture

```
┌──────────────┐  DB Webhook     ┌─────────────┐  invoke      ┌──────────────────┐  HTTP/2+JWT  ┌─────────┐
│  Postgres    │ ──────────────▶ │  Supabase   │ ───────────▶ │ send-push-       │ ───────────▶ │  APNs   │
│  (triggers)  │                 │  Edge Fn    │              │ notification    │              │         │
└──────────────┘                 └─────────────┘              └──────────────────┘              └────┬────┘
                                                                                                      │
                                                                                             ┌────▼────┐
                                                                                             │ iPhone  │
                                                                                             └─────────┘
```

The DB is the single source of truth: if a row is inserted, push is attempted; if the row is never written (e.g. RLS blocks it), no push is attempted. The iOS client never directly calls the push function.

## 5. Database Schema

### 5.1 `profiles` additions

```sql
ALTER TABLE profiles
  ADD COLUMN device_token TEXT,
  ADD COLUMN push_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN apns_environment TEXT NOT NULL DEFAULT 'production'
    CHECK (apns_environment IN ('sandbox', 'production'));

CREATE INDEX idx_profiles_device_token
  ON profiles(device_token) WHERE device_token IS NOT NULL;
```

- `device_token`: hex APNs token, set by iOS on every launch (idempotent).
- `push_enabled`: master switch. The edge function early-returns if false.
- `apns_environment`: set by iOS to `sandbox` for debug builds, `production` for release. Drives the APNs host the edge function targets.

### 5.2 `notification_prefs` (new table)

```sql
CREATE TABLE notification_prefs (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  push_messages    BOOLEAN NOT NULL DEFAULT true,
  push_interests   BOOLEAN NOT NULL DEFAULT true,
  push_offers      BOOLEAN NOT NULL DEFAULT true,
  push_completions BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE notification_prefs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own prefs"
  ON notification_prefs FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users update own prefs"
  ON notification_prefs FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users insert own prefs"
  ON notification_prefs FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION ensure_notification_prefs()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO notification_prefs (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END $$;

CREATE TRIGGER tr_profiles_ensure_prefs
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION ensure_notification_prefs();
```

Auto-created on profile insert. A one-time backfill migration inserts default rows for any existing profiles.

### 5.3 `conversation_mutes` (new table)

```sql
CREATE TABLE conversation_mutes (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  muted_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

ALTER TABLE conversation_mutes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own mutes"
  ON conversation_mutes FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users mutate own mutes"
  ON conversation_mutes FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_conversation_mutes_user ON conversation_mutes(user_id);
```

### 5.4 `push_log` (new debug table)

```sql
CREATE TABLE push_log (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  event TEXT NOT NULL,
  target_user_id UUID,
  delivered BOOLEAN NOT NULL,
  reason TEXT,
  apns_status INT,
  apns_id TEXT
);

ALTER TABLE push_log ENABLE ROW LEVEL SECURITY;
-- No SELECT for authenticated role; service_role only.
```

### 5.5 Triggers → edge function

One Postgres trigger per event type. Each trigger calls a Supabase Database Webhook, which in turn invokes the `send-push-notification` edge function with a small JSON payload. Webhooks are configured in `supabase/config.toml` (or via the Dashboard) so the deploy is reproducible.

Trigger function shape (one per event):

```sql
CREATE OR REPLACE FUNCTION trigger_interest_push()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  PERFORM supabase_functions.http_request(
    'https://<project-ref>.supabase.co/functions/v1/send-push-notification',
    'POST',
    jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    'application/json',
    jsonb_build_object(
      'event', 'interest_created',
      'interest_id', NEW.id,
      'job_id', NEW.job_id,
      'from_user_id', NEW.user_id
    )::text
  );
  RETURN NEW;
END $$;

CREATE TRIGGER tr_job_interests_push
  AFTER INSERT ON job_interests
  FOR EACH ROW EXECUTE FUNCTION trigger_interest_push();
```

Equivalent triggers on `messages`, `deals`, and `completion_requests` (added in the same migration). The migration also does:

```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
```

`app.service_role_key` is set via `ALTER DATABASE postgres SET app.service_role_key = '<jwt>';` during deploy. The webhooks approach is preferred over calling `net.http_post` directly from the trigger because the Dashboard shows webhook invocations, retries, and logs without writing custom observability.

## 6. Edge Function: `send-push-notification`

**Location:** `supabase/functions/send-push-notification/index.ts`
**Runtime:** Deno (matches existing `Web/supabase/functions/bkash-*` pattern).

### 6.1 Inputs

Two call shapes:

1. **From DB triggers** (main path). Body:
   ```json
   { "event": "interest_created", "interest_id": "...", "job_id": "...", "from_user_id": "..." }
   ```
   Other events: `message_created`, `offer_created`, `completion_requested`.

2. **Debug entrypoint** (only when `X-Debug-Key` header matches a Supabase secret). Body:
   ```json
   { "to_user_id": "...", "title": "...", "body": "...", "notification_type": "...", "data": { ... } }
   ```

The iOS client's existing direct call (`NotificationsNetworking.swift:1233-1262`) is removed in a final commit; v1 ships with DB triggers as the only production path.

### 6.2 Flow

```
1. Parse body → determine event
2. Resolve target user_id:
   - DB trigger shape: derive from event
     - interest_created: SELECT job_poster_id FROM jobs WHERE id = NEW.job_id
     - message_created: the other participant in the conversation
     - offer_created: deal seeker (non-offerer)
     - completion_requested: deal provider
   - Debug shape: use to_user_id directly
3. Check master switch: SELECT push_enabled FROM profiles WHERE id = target
4. Check category pref: SELECT notification_prefs.push_<category> WHERE user_id = target
5. For 'message_created': also check conversation_mutes (skip if muted)
6. SELECT device_token, apns_environment FROM profiles WHERE id = target
7. If any check fails or token is null → 200 { delivered: false, reason: ... }
8. Sign APNs JWT (ES256, .p8 key) — cache 50 min, refresh on expiry
9. POST to https://api{sandbox,}..push.apple.com/3/device/<token>
   Headers:
     authorization: bearer <jwt>
     apns-topic: <bundle id>
     apns-push-type: alert
     apns-priority: 10
     apns-expiration: 0
   Body: standard APNs alert payload + custom `data` object
10. Log to push_log; on 410 (Unregistered) or 400 BadDeviceToken →
    UPDATE profiles SET device_token = NULL WHERE id = target
11. Return 200 { delivered: true|false, ... }
```

### 6.3 Event → APNs payload mapping

| Event | Title | Body | data.* | apns-push-type | category |
|---|---|---|---|---|---|
| `interest_created` | "New interest on your job" | "{sender_name} is interested" | `{ type, job_id, user_id, notification_id }` | `alert` | `INTEREST_REQUEST` |
| `message_created` | "{sender_name}" | first 80 chars of body | `{ type, conversation_id, message_id }` | `alert` | `NEW_MESSAGE` |
| `offer_created` | "New offer received" | "{sender_name} offered ৳{amount}" | `{ type, deal_id, user_id, notification_id }` | `alert` | `OFFER_RECEIVED` |
| `completion_requested` | "Completion requested" | "Tap to review" | `{ type, deal_id, notification_id }` | `alert` | `PROFILE_NOTIFICATION` |

`aps.alert.title` and `aps.alert.body` are used (not the deprecated top-level `alert`).

### 6.4 APNs environment

```ts
const base = profile.apns_environment === 'sandbox'
  ? 'https://api.sandbox.push.apple.com'
  : 'https://api.push.apple.com'
```

### 6.5 JWT caching

```ts
const TOKEN_TTL_MS = 50 * 60 * 1000
let cachedJwt: { token: string, expires: number } | null = null

function getApnsJwt(): string {
  if (cachedJwt && cachedJwt.expires > Date.now()) return cachedJwt.token
  cachedJwt = { token: sign(...), expires: Date.now() + TOKEN_TTL_MS }
  return cachedJwt.token
}
```

### 6.6 Secrets (Supabase secrets)

- `APNS_KEY_ID` — 10-char Key ID from Apple Developer.
- `APNS_TEAM_ID` — 10-char Team ID.
- `APNS_BUNDLE_ID` — `com.kajhobe.app` (must match Xcode).
- `APNS_KEY_P8` — contents of the `.p8` file with newlines escaped as `\n`.
- `PUSH_DEBUG_KEY` — shared secret enabling the debug entrypoint.

### 6.7 Response shape

```ts
// 200 OK
{ delivered: true,  apns_id: "...", event: "message_created" }
{ delivered: false, reason: "muted" | "disabled" | "no_token" | "preference_off" | "apns_error", apns_status: 410 }
```

All paths return 200. A 500 from this function would surface in `push_log` but does not break the DB write that triggered the call.

### 6.8 Failure handling

| APNs status | Action |
|---|---|
| 200 | log success |
| 410 Unregistered | null out `profiles.device_token` |
| 400 BadDeviceToken | null out `profiles.device_token` |
| 403 InvalidProviderToken | drop cached JWT so next call regenerates |
| 429 TooManyRequests | log, return 200 (next event will retry) |
| other 4xx/5xx | log, return 200 |

Push failure never propagates to the trigger — by design.

## 7. iOS Client

### 7.1 New `AppDelegate.swift`

The current project has no `AppDelegate`. Without `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`, the OS callback that delivers the APNs token never reaches the app, and `profiles.device_token` stays null forever. This is the #1 root cause of the current broken state.

```swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    PushNotificationManager.shared.setupNotificationCategories()
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(withError: error)
  }
}
```

In `KajHobeApp.swift`:

```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

`setupNotificationCategories()` moves from the existing `KajHobeApp.swift:22` call into `AppDelegate.didFinishLaunching` so it runs on cold launch before any view appears.

### 7.2 `PushNotificationManager.swift` edits

- `sendDeviceTokenToSupabase()` (`PushNotificationManager.swift:86-119`) — keep, already idempotent. Add `apns_environment` to the update payload: `Bundle.main.environment == .debug ? "sandbox" : "production"`.
- `requestNotificationPermission()` (`PushNotificationManager.swift:31-49`) — keep, still called on login (`KajHobeApp.swift:120`). Add a one-time first-launch prompt for users who declined.
- `checkNotificationPermission()` (`PushNotificationManager.swift:51-60`) — keep, used on `didBecomeActive` (`KajHobeApp.swift:79-83`).
- `scheduleInteractiveNotification()` and `scheduleLocalNotification()` — keep; useful for local confirmations and the `Action Complete` toast that already runs after an interest response (`PushNotificationManager.swift:404-408`).

### 7.3 `NotificationSettingsView.swift` edits

The view exists. Add four `Toggle` rows for `push_messages`, `push_interests`, `push_offers`, `push_completions`, backed by a new `NotificationPreferences` model loaded from `notification_prefs` and saved via a thin `NotificationPreferencesNetworking` on `BaseNetworking`. If `deviceToken == nil`, show a one-time banner "Notifications not available on this device" (simulators don't get tokens).

### 7.4 Per-conversation mute

In `MessagesView`, long-press on a conversation row opens a context menu with "Mute notifications" / "Unmute notifications". Tapping toggles a row in `conversation_mutes`. The edge function consults this table for `message_created` events.

### 7.5 Removal of iOS direct call

After the DB trigger path is verified end-to-end on a real device, remove `sendPushNotification()` (`NotificationsNetworking.swift:1233-1262`) and any callers. The edge function then has one call path: DB webhook. This eliminates the case where the client reports "push sent" but the DB write that should have driven it was actually rejected by RLS.

### 7.6 Xcode project

- Add `KajHobe/AppDelegate.swift` to the `KajHobe` target.
- Confirm **Background Modes → Remote notifications** is enabled in the target's Signing & Capabilities tab. Required for the OS to deliver a tap on a terminated-app notification back to the app.
- No Info.plist or entitlements changes — `aps-environment`, `aps-push-type` capabilities, and the communication/critical-alerts/time-sensitive entitlements are already in `KajHobe.entitlements`.

## 8. Required Apple Setup (one-time, ~5 min)

The user runs these in Apple Developer → Certificates, Identifiers & Profiles → Keys:

1. Click **+** to create a new key.
2. Name: "KajHobe APNs". Check **Apple Push Notifications authentication key (APNs)**. Click Continue → Register.
3. Download the `.p8` file. Store safely — Apple only shows it once.
4. Note the **Key ID** (10 chars) and the **Team ID** (10 chars, top-right of the developer account page).
5. Confirm the **Bundle ID** registered for the app matches `APNS_BUNDLE_ID` (e.g. `com.kajhobe.app`).
6. Provide the `.p8` file contents, Key ID, Team ID, and Bundle ID to the deploy step. The deploy step sets Supabase secrets `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`.

## 9. Testing

| Layer | Test |
|---|---|
| Edge function (logic) | `curl` with `X-Debug-Key` and a fake `to_user_id`; assert 200 + `delivered: false, reason: "no_token"` |
| APNs handshake | Same curl with a real device token; assert 200 + APNs response; assert JWT sign/refresh works |
| DB triggers | `supabase_execute_sql` insert into `job_interests`; assert a new `push_log` row appears within 2s |
| iOS delivery (real device) | Build dev scheme on iPhone. From a second account, send a message / interest / offer. Assert: Lock Screen banner, badge increments, sound plays, tap deep-links correctly |
| Prefs | Toggle Messages off → trigger message → assert no push. Toggle back on → assert push |
| Mute | Mute a conversation → trigger message in that thread → assert no push. Other conversations still push |
| Token invalidation | Uninstall app, reinstall on same device, trigger push → assert APNs returns 410, then `profiles.device_token` is null |
| `apns_environment` | Build debug → trigger push → assert edge function logs show `api.sandbox.push.apple.com`. Build release → assert production host |

## 10. Rollout

1. **Migrations** (push columns, prefs, mutes, `push_log`, backfill for existing profiles). Triggers present but inert — no edge function exists yet.
2. **Edge function deployed** in a Supabase branch. Smoke test via `curl`.
3. **Webhooks wired** to triggers. Test in branch database first.
4. **iOS build** with new `AppDelegate`. Test on real device against the branch.
5. **Merge branch to production.**
6. **Settings UI** (per-category toggles, per-conversation mute) added in a separate small PR.
7. **Removal of iOS direct call** in a final commit, after the DB path is verified.

At no point during rollout is the system in a half-working state where some events push and some don't: until step 3, no events push; after step 3, all configured events push.

## 11. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Apple rejects `.p8` key generation or entitlement | `aps-environment` entitlement is already configured and accepted; this risk is minimal |
| APNs JWT signing format drift | Use a maintained library (e.g. `djwt` for Deno); test against `api.sandbox.push.apple.com` first |
| DB Webhook rate limits | Supabase webhooks handle bursts; APNs has its own per-device throttling we cannot exceed anyway |
| User uninstalls → stale device_token causes APNs 410s | Edge function nulls out the token on first 410; no per-event spam |
| Per-conversation mute lookup adds latency to every message push | `conversation_mutes` is indexed by `user_id`; the join is cheap; not on the critical path of message delivery (which goes through real-time channels) |
| Service role key in DB setting is read by trigger functions | Setting is `ALTER DATABASE` scoped; only the trigger function reads it. Trigger function is `SECURITY DEFINER` so it runs as the function owner. Acceptable for a single-tenant app |
| Push title/body in English only | Documented; trivially addable later via a `aps.alert.title-loc-key` style flow |
| iOS Simulator can't receive push | Show banner in `NotificationSettingsView` when `deviceToken == nil` |

## 12. Open Questions

None at design time. Implementation may surface questions about the exact existing schemas (`job_interests`, `deals`, `messages`, `completion_requests`, `conversations`) — those are resolved in the implementation plan.
