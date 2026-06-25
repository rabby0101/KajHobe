# KajHobe Web → iOS Feature Parity — Design Spec

**Date:** 2026-06-16
**Author:** Sk Fazla Rabby (with Claude)
**Status:** Approved design — ready for implementation plan

## 1. Goal

Bring the existing KajHobe **web app** (`Web/`) to full feature parity with the
**iOS app** (`iOS/`). Both already run against the same Supabase backend
(`xatlqnbrvgukuqewsxux`). This is a **gap-closing** effort on a live, shared-backend
web app — not a greenfield build.

User decisions driving this spec:
- **Full parity in one plan** (not phased into separate specs).
- **Build directly** — do not block on first verifying/running the existing app.
- **Payments (bKash escrow) included** at normal priority.

## 2. Current state

### 2.1 Stack (keep as-is)
- **Web:** React 18, Vite, TypeScript, shadcn/ui (Radix), Tailwind, TanStack Query,
  react-router-dom v6, `@supabase/supabase-js` v2, `recharts` (already a dependency),
  Capacitor (iOS/Android shells).
- **Backend:** Supabase Postgres + Auth + Storage + Realtime + Edge Functions.
- **iOS:** SwiftUI + MVVM, Supabase Swift SDK. Domain-split networking classes.

### 2.2 What web already has
Auth; Browse/Category/Post jobs; MyJobs; Messages + chat (offers, counter-offers,
negotiation, image upload); Deals/Proposals; a basic NotificationCenter; Dashboard
(active/completed counts, earnings/dispute splits — but **hardcoded average rating**);
Profile; Settings; bottom navigation; Theme + Language contexts (`en`/`bn` only).

### 2.3 Mapping convention
Each iOS networking class maps to a **web hook** (`use*`) plus its page/component,
mirroring the existing `useDeals` / `useJobs` / `useConversations` pattern. New screens
follow the existing `pages/` + `components/` layout and shadcn primitives.

### 2.4 Relevant backend tables (confirmed via MCP)
`profiles`, `jobs`, `service_categories`, `reviews`, `proposals`, `notifications`,
`deals`, `conversations`, `messages`, `job_interests`, `job_views`, `deal_offers`,
`completion_requests`, `push_notifications`, `public_profiles`, `job_bookmarks`,
`app_admins`, `escrow_transactions`, `escrow_events`, `provider_payout_accounts`,
`deal_disputes`.

## 3. Workstreams

Each workstream lists: iOS source of truth, parity requirements, web implementation,
and the backend surface it talks to.

### W1 — Public profiles + trust levels  *(greenfield)*
- **iOS:** `PublicProfileNetworking.swift`, `PublicProfileView.swift`,
  `Views/PublicProfileComponents.swift`; `TrustLevel` enum.
- **Backend:** `public_profiles` table (materialized stats: `completed_jobs`,
  `avg_rating`, `total_earnings`, `avg_job_value`, `review_count`, `is_online`,
  `last_seen_at`, `average_response_time_minutes`, `service_categories`, `trust_level`).
- **Trust tiers (mirror server thresholds):** unverified → newcomer (≥1 job) →
  established (≥5 jobs & ≥3.5★) → experienced (≥10 & ≥4.0★) → expert (≥20 & ≥4.5★).
- **Web:**
  - `hooks/usePublicProfile.ts` — fetch single profile + batch summaries.
  - `components/TrustBadge.tsx` — color-coded 5-tier badge (gray→blue→green→orange→purple).
  - `components/PublicProfileCard.tsx` — compact card (avatar, name, badge, rating, jobs).
  - `pages/PublicProfile.tsx` at route `/provider/:id` — hero, stats, bio, categories,
    service highlights, activity.
  - Embed `PublicProfileCard` inside interest-request notifications.

### W2 — Reviews  *(greenfield)*
- **iOS:** `Views/Reviews/ReviewSheet.swift`, `StarRatingInput.swift`;
  `PublicProfileNetworking.submitReview(jobId, reviewedId, rating, comment)`.
- **Backend:** `reviews` table.
- **Behavior:** rating 1–5 required, comment optional; guards `alreadyReviewed` and
  `jobNotCompleted`; success state + dismiss; "Maybe later" skip.
- **Web:**
  - `hooks/useReviews.ts` — `submitReview`, fetch reviews for a user/job.
  - `components/StarRatingInput.tsx` — tappable 5-star input.
  - `components/ReviewDialog.tsx` — shadcn `Dialog` mirroring `ReviewSheet`.
  - **Triggers:** auto-prompt after a deal completes; "Leave review" button on completed
    deals (Dashboard + deal detail). Review summaries surface on public profiles.

### W3 — Dashboard analytics  *(upgrade)*
- **iOS:** `Views/Dashboard/DashboardAnalytics.swift`, `DashboardChartsSection.swift`,
  `DashboardReputationCard.swift`, `DealsListView.swift`.
- **Parity requirements (port the pure aggregations):**
  - **Monthly money flow** — earned vs spent per month (completed deals only;
    provider→earned, client→spent). Bar chart.
  - **Status breakdown** — deals grouped by lifecycle state. Donut.
  - **Rating trend** — cumulative running average per month. Line.
  - **Rating distribution** — counts per star (5→1). Bars.
  - **Trust level + next-tier progress** — current tier and what's needed for the next.
- **Web:**
  - `lib/dashboardAnalytics.ts` — pure functions mirroring the Swift aggregations
    (unit-testable, the single swap point if volume grows).
  - `components/dashboard/MoneyFlowChart.tsx`, `StatusDonut.tsx`, `RatingTrendChart.tsx`,
    `RatingDistribution.tsx`, `ReputationCard.tsx` (all `recharts`).
  - **Fix:** replace hardcoded `average_rating: 4.5` in `pages/Dashboard.tsx` with real
    review-derived rating.

### W4 — Presence  *(greenfield)*
- **iOS:** `PresenceManager.swift` — periodic DB writes (`is_online`/`last_seen`) every
  5 min + on app active/resign; response-time calc hourly.
- **Transport decision:** **periodic DB writes** (behavioral parity with iOS), not
  Realtime presence channels.
- **Web:**
  - `hooks/usePresence.ts` — set online on mount/focus, offline on hide/unmount;
    interval refresh; uses `visibilitychange`/`focus`/`blur` + `beforeunload`.
  - Online dots + "last seen" rendering in conversation list, chat header, profile cards.

### W5 — Interest cooldown  *(greenfield)*
- **iOS:** `InterestCooldownManager.swift`, `CooldownTimerView.swift`.
- **Rules (port exactly):** cooldown 120s, max 2 attempts → permanent block,
  rate limit 60s between attempts. Status derived from `job_interests` (pending/accepted
  blocks) + `notifications` (`type = show_interest`, rejected count, timestamps).
- **Web:**
  - `lib/interestCooldown.ts` — `checkCooldownStatus`, `validateInterestAttempt`,
    `recordRejection`, time formatting, progress calc.
  - `components/CooldownTimer.tsx` — countdown UI on the "Show Interest" button.
  - Integrate into the existing show-interest action (JobCard / job detail).

### W6 — Enhanced notifications  *(upgrade)*
- **iOS:** `NotificationsView.swift`, `Views/NotificationComponents.swift`,
  `NotificationsNetworking.swift`, `Managers/NotificationBadgeManager.swift`.
- **Parity requirements:** three states (unread/read/archived) with tabs + counts;
  interactive Accept/Reject for interest requests; informational vs interactive types;
  time grouping (Today/Yesterday/…); realtime subscription; live badge counts;
  "mark all as read"/bulk archive.
- **Web:** upgrade `components/NotificationCenter.tsx` + `pages/Notifications.tsx`;
  extend `hooks/useNotifications.ts` with state transitions, action handling, realtime
  channel, and a badge count source consumed by `BottomNavigation`.

### W7 — Archived conversations  *(greenfield)*
- **iOS:** `Views/ArchivedConversationsView.swift`.
- **Web:** archive/unarchive action + an "Archived" tab in `pages/Messages.tsx` /
  `components/chat/ConversationList.tsx`; extend `useConversations`.

### W8 — Completion requests  *(verify + complete)*
- **iOS:** `CompletionRequestView.swift`; `completion_requests` table.
- **Web:** web has partial coverage (Notifications + Dashboard). Verify and complete the
  full request → approve/reject flow, including the requester and approver views and the
  resulting deal status transition.

### W9 — Media  *(upgrade)*
- **iOS:** `Views/MediaCarouselView.swift`, `MediaPickerView.swift`, `CameraView.swift`.
- **Web:** image carousel for multi-image messages and job posts (embla is already a
  dependency); confirm upload/camera parity via existing `ImageUpload`/Capacitor Camera.

### W10 — Internationalization  *(upgrade)*
- **iOS:** `en` / `bn` / `de` (`LanguageManager.swift`, `*.lproj/Localizable.strings`).
- **Web today:** `en` / `bn` only (`contexts/LanguageContext.tsx`).
- **Web:** add the `de` structure for parity. **Lowest priority:** full German copy is
  optional — German is an odd fit for a Khulna marketplace. Implement the slot; copy can
  follow.

### W11 — Escrow / bKash payments  *(greenfield — build last-ish)*
- **iOS:** `Payments/EscrowNetworking.swift`, `PaymentProvider.swift`,
  `EscrowSectionView.swift`, `BkashCheckoutSession.swift`; "Accept & Pay" in `ChatView`.
- **Backend:** `escrow_transactions`, `escrow_events`, `provider_payout_accounts`,
  `deal_disputes`, `app_admins`; Edge Function `bkash-collect`; RPCs
  `escrow_mark_paid_out`, `escrow_mark_refunded`, `is_admin`.
- **Flows:**
  - **Collection (client pays at offer acceptance):** "Accept & Pay" invokes
    `bkash-collect` with `deal_offer_id` → returns `{ bkash_url, payment_id }` → redirect
    the browser to `bkash_url`. The webhook captures payment, **then** creates the deal and
    holds escrow. Web handles the return/callback URL and reflects status.
  - **Escrow status card:** reads `escrow_transactions` for a deal; renders 7 states
    (pending/held/released/paid_out/refunded/failed/resolved) with role-aware copy.
  - **Payout account:** view/upsert the current user's bKash number
    (`provider_payout_accounts`, owner-only via RLS; format `01XXXXXXXXX`).
  - **Admin actions:** mark paid-out / refunded via the SECURITY DEFINER RPCs, shown only
    when `is_admin` returns true.
- **Web:**
  - `hooks/useEscrow.ts` (fetch escrow, fetch my escrows, start collection, admin
    payout/refund, payout-account get/upsert, admin check).
  - `components/payments/EscrowSection.tsx`, `PayoutAccountForm.tsx`,
    `AcceptAndPayButton.tsx`.
  - **Dependency:** needs a deal-detail surface (see §4) to host the escrow card.

## 4. Cross-cutting additions

- **Deal-detail route:** web currently has no deal-detail page (iOS uses
  `DealDetailView`). Add `pages/Deal.tsx` at `/deal/:id` to host the escrow card,
  completion-request actions, and the "Leave review" entry point. Register in `App.tsx`.
- **Provider-profile route:** `/provider/:id` (W1).
- **Badge wiring:** `BottomNavigation` consumes live unread counts for Messages and
  Notifications (parity with iOS tab badges).

## 5. Build sequence (one plan, dependency-ordered)

1. **W1** Public profiles + trust (foundation for reviews, dashboard, notifications)
2. **W2** Reviews
3. **W3** Dashboard analytics (consumes W1/W2 data)
4. **W4** Presence
5. **W5** Interest cooldown
6. **W6** Enhanced notifications
7. **W7** Archived conversations
8. **W8** Completion requests (+ `/deal/:id` route)
9. **W9** Media + **W10** i18n structure
10. **W11** Escrow / bKash (depends on `/deal/:id`; riskiest, needs sandbox + edge fn)

## 6. Non-goals / explicitly out of scope

- Native iOS/Android Capacitor packaging changes beyond what web parity requires.
- New backend schema design — the tables/RPCs/edge functions already exist; web consumes
  them. (Only exception: the optional RLS fix in §8, which is the user's call.)
- Full German translation copy (structure only; see W10).
- Redesigning the existing web UI; new screens follow current shadcn patterns.

## 7. Testing & verification

- **Pure logic** (`lib/dashboardAnalytics.ts`, `lib/interestCooldown.ts`): unit tests
  mirroring the Swift behavior (month bucketing, running average, cooldown thresholds).
- **Hooks:** smoke-tested against the live backend (read paths) and with the dev server.
- **Per workstream:** manual click-through of the flow in the dev server before moving on,
  plus `npm run lint` / `tsc` clean.
- **Escrow:** verified end-to-end against the bKash **sandbox** only; admin actions tested
  with an `app_admins` account.

## 8. Risks & open items

- **⚠️ Security — RLS disabled on `public.service_categories`:** the table is fully exposed
  to the anon key (read/write). Remediation:
  ```sql
  ALTER TABLE public.service_categories ENABLE ROW LEVEL SECURITY;
  -- plus a read policy, e.g.:
  CREATE POLICY "service_categories are readable by everyone"
    ON public.service_categories FOR SELECT USING (true);
  ```
  **Not auto-applied** — enabling RLS without a policy blocks all access. User decides
  whether/when to run it. (Web reads categories from `lib/categories.ts` today, so a
  read-only policy is low-risk.)
- **bKash dependency:** assumes the `bkash-collect` Edge Function and the escrow RPCs are
  deployed and the sandbox is configured. Verify before W11; if missing, that becomes a
  backend prerequisite task.
- **bKash redirect model:** web uses a full-page redirect + return URL (vs the iOS
  in-app `BkashCheckoutSession`). The return/callback handling is the main new surface.
- **German parity:** low value; structure-only unless the user wants full copy.
- **Presence cost:** periodic DB writes per active client — interval tuned to iOS (5 min)
  to avoid write amplification.
