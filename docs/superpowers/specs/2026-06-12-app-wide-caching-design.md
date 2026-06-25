# App-Wide Stale-While-Revalidate Caching (iOS)

**Date:** 2026-06-12
**Status:** Approved
**Scope:** iOS app (`iOS/KajHobe/`)

## Problem

The app has a proven disk + memory cache pattern (`JobsCache`, `ConversationsCache`) that makes the Jobs home screen and Messages list paint instantly, but every other data-driven screen re-fetches from the network on every visit and shows a spinner:

| Screen | Today |
|---|---|
| Dashboard | Always fetches with `forceRefresh: true`; comment "Cache has been removed" (`DashboardView.swift`) |
| Notifications | Full re-fetch on every load |
| Profile | Re-fetch on every `.onAppear`, plus a *serial* second network call for the payout number |
| Chat | Blank `isLoading` state on every conversation open |

The result is visible lag and spinners throughout the app even though the data rarely changes between visits.

## Goal

Every main screen paints instantly from a local cache and refreshes from the network in the background. Spinners appear only on a true first launch (empty cache). Stale data (seconds-to-minutes old) is acceptable by design because a network refresh always follows immediately.

## Design

### 1. `UserScopedDiskCache<T: Codable>` (new file, ~90 lines)

A generic extracted from the proven `ConversationsCache` design:

- In-memory mirror (fast path) + JSON file in the Caches directory (cold-start path).
- `NSLock`-guarded synchronous memory access; disk I/O on detached utility tasks.
- Payload tagged with the owning `userId`; `peek`/`load` return data only when the stored owner matches the current user.
- API: `peek(userId:)`, `load(userId:) async`, `save(_:userId:)`, `clear()`.
- Decode failures behave as a cache miss (`try?`), never a crash — a model change just causes one slow load.

`JobsCache` and `ConversationsCache` remain untouched (working code, no churn).

### 2. Four cache instances built on the generic

| Cache | Payload | Keyed by |
|---|---|---|
| `DashboardCache` | one combined Codable struct: `DashboardData` + `[DealWithCompletion]` | user |
| `NotificationsCache` | raw fetch results: `[JobInterestNotification]` + `[BusinessNotification]` | user |
| `ProfileCache` | `Profile` + payout number (combined struct) | user |
| `ChatMessagesCache` | last 50 `[ChatMessage]` per conversation | user + conversation id (one file per conversation, e.g. `chat_messages_<conversationId>.json`) |

**Notifications note:** the display model `UnifiedNotification` holds `[String: Any]` and closures, so it cannot be serialized. We cache the upstream Codable source arrays and let the existing build logic derive the unified list. This keeps the cache dumb and the display logic in one place.

### 3. Per-screen flow (identical everywhere)

```
appear → peek() — if hit: paint instantly, NO spinner
       → network refresh in background → update UI + save()
       → spinner only when cache is empty (true first launch)
```

Screen specifics:

- **Dashboard:** drop the always-on `forceRefresh: true`; cached paint then refresh. Existing realtime events keep triggering refreshes.
- **Notifications:** cache raw fetch results; badge counts keep coming from the existing realtime path.
- **Profile:** cache + fix the serial fetch — fetch profile and payout number in parallel with `async let`.
- **Chat:** paint cached history instantly on conversation open; the network fetch reconciles (replaces) it; realtime inserts also update the cache so the next open is current.

### 4. Invalidation & safety

- **Sign-out:** all four caches `clear()`, wired at the same place `ConversationsCache.clear()` is already called.
- **User-scoping** guarantees a different account on the same device never sees stale foreign data.
- **Writes** (accept/reject, send message, edit profile) always go to network first, then update the cache.

### 5. Hygiene cleanup (bundled in the same branch)

- Delete `KajHobe/NotificationsView.swift.backup`.
- Delete `KajHobe/PremiumJobCard.swift.disabled`.
- Strip the ~190 lines of commented-out dead code from `KajHobe/LocalStorageManager.swift`.

## Out of Scope

- Job detail / Deal detail screens (load context fresh; revisit later if needed).
- Offline-first local database (SwiftData/GRDB) — long-term option, deferred until the feature set stabilizes.
- Android/Web parity (separate effort).

## Testing

- Unit tests for `UserScopedDiskCache`: round-trip, user-scope rejection (different `userId` returns `nil`), `clear()` wipes memory and disk.
- Build verification via `xcodebuild` (scheme `KajHobe`, iPhone 16 simulator).
- Manual verification per screen: visit → kill app → revisit → instant paint, then background refresh lands.
