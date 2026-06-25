# KajHobe — Deal Lifecycle Workflow & Gap Analysis

> **Status:** Reference document. Captures the end-to-end marketplace workflow as it
> exists in code today, every branch/edge case, and the open risks — with extra
> depth on (A) money-stuck / disputes and (B) dangling providers & job state.
> No remediation has been implemented; the "missing piece" / "what good looks like"
> notes are proposals, not current behaviour.

## Context / why this exists

KajHobe runs an escrow-backed local-services marketplace: a poster posts a job,
multiple providers compete, a deal is struck with one of them, the buyer's money is
held by the platform, and an admin manually pays the provider after both sides agree
the work is done. The flow spans five separate state machines stitched together by
Postgres triggers, plus a localhost admin payout panel. Because several of those
stitches are incomplete, money can get stuck and losing providers are left dangling.
This document maps the whole thing so we can decide what to harden first.

---

## 1. Actors & roles

- **Job poster / client** — posts a job, reviews interests, invites providers to
  chat, accepts an offer, pays into escrow, approves completion.
- **Service provider** — `profiles.is_service_provider = true`. Self-assigned via a
  profile toggle; **no verification gate** (`ProfileNetworking.swift:46`,
  `ProfileView.swift:88`). Shows interest, chats, sends offers, requests completion,
  receives payout.
- **Admin** — listed in `app_admins`. Uses the localhost payout panel
  (`Web/admin-payout-prototype/`) to release money manually via bKash, and is the
  **only** actor who can refund.

---

## 2. The five state machines

| Table | Statuses | Driven by |
|---|---|---|
| `job_interests` | `pending → accepted / rejected` (reusable row, `UNIQUE(job_id, provider_id)`) | `NotificationsNetworking` |
| `conversations` | `active` (+ per-user `client_archived` / `provider_archived`) | trigger on interest accept |
| `deal_offers` | `pending → accepted / rejected` | `DealsNetworking.createDealOffer` |
| `deals` | `status: active → completed`; `completion_status: in_progress → pending_approval → completed / disputed` | offer-accept trigger + completion RPCs |
| `completion_requests` | `pending → approved / rejected` (one pending per deal) | `DealsNetworking.requestTaskCompletion` |
| `escrow_transactions` | `pending → held → released → paid_out` (side: `refunded`, `failed`) | escrow RPCs + deal triggers |

Key insight: **`escrow_transactions` is a money ledger separate from the deal.** A
deal can move on while escrow lags behind (or vice-versa) — that decoupling is the
source of most "stuck money" cases.

---

## 3. Happy path (end to end)

```
1. Poster posts job          → jobs.status = 'open'
2. Provider shows interest   → job_interests (pending)  + notification to poster
3. Poster accepts interest   → job_interests.status = 'accepted'
                             → trigger creates conversations row (active)
4. They chat
5. Provider sends offer       → deal_offers (pending) + 'deal_offer' message
6. Poster accepts + PAYS      → bKash collection → escrow_finalize_offer()
                             → deal_offers.status = 'accepted'
                             → trigger creates deals (active)
                             → trigger creates escrow_transactions (pending)
                             → webhook flips escrow pending → held
                             → jobs.status = 'assigned'
7. One party requests done    → completion_requests (pending)
                             → deals.completion_status = 'pending_approval'
                             → notification to the OTHER party
8. Other party APPROVES       → completion_requests.status = 'approved'
                             → deals.status = 'completed', jobs.status = 'completed'
                             → trigger flips escrow held → released
                             → snapshots provider bKash number (provider_payout_accounts)
9. Admin pays out (localhost) → escrow released → paid_out
```

---

## 4. Branch-by-branch: every situation

### Q1 — User is NOT a service provider
- `is_service_provider` defaults `false`; the "Show Interest" button is hidden when
  false (`JobDetailView` ~519). The only hard guard is self-interest blocking
  (`NotificationsNetworking.swift:733`).
- **Role is self-assigned with zero verification** — a one-tap toggle. UI-only
  gating; a direct API call bypasses it.

### Q2 — Poster rejects an interest
- `respondToInterest(accept:false)` (`NotificationsNetworking.swift:1110`):
  `job_interests.status → rejected`, `actioned_at` set; `interest_rejected`
  notification sent to provider **(non-blocking — fails silently if push errors)**.
- Row not deleted. **5-minute cooldown**, then provider may re-apply (row reused →
  `pending`). `UNIQUE(job_id, provider_id)` prevents duplicate interest rows.

### Q3 — Deal created between provider & poster
- See steps 5–6 above. `jobs.status → 'assigned'` (no "filled"/"closed").
- Jobs list filters out any job with a deal in
  `accepted/in_progress/active/completed` (`JobsNetworking.swift:27–48`) — **list
  view only.**

### Q4 — Multiple conversations on one job
- Fully supported & intended: each accepted interest spawns its own conversation
  (same `job_id`, different provider). No cap; uniqueness is on interests not convos.
- **GAP:** when a deal is struck with Provider A, Providers B/C are untouched —
  conversations stay `active`, interests stay `accepted`, no notification, they can
  keep messaging a job that's already gone. Archive exists but is **manual**
  (`MessagesNetworking.swift:700`), never auto-fired.

### Q5 — Completion requested, other party rejects
- `respondToCompletionRequest(approve:false)` (`DealsNetworking.swift:466`):
  request → `rejected`; deal rolls back fully to `active` / `in_progress`, both
  `*_completion_requested` flags cleared; `completion_rejected` notification sent.
- Either side may re-request, **unlimited**. Escrow stays `held` throughout.
- **No dispute mechanism.** `disputed` status exists but is unused → permanent
  disagreement = money held forever, admin-only manual exit.

---

## 5. FOCUS A — Money-stuck / disputes (high priority)

Concrete ways money gets trapped today, with the trigger and the missing exit:

| # | Scenario | Escrow ends at | Why it's stuck | Missing piece |
|---|---|---|---|---|
| A1 | **Stalemate** — completion requested→rejected→re-requested→rejected, repeat | `held` | Deal rolls back to `active` each time; no cap, no arbiter | Dispute escalation → admin; wire up the reserved `disputed` status |
| A2 | **Ghosting** — one side requests, other goes silent | `held` (`pending_approval` forever) | No timeout on a pending completion request | Auto-approve-after-N-days, or admin nudge/override |
| A3 | **Payment failed at accept** | `pending` | Offer accepted but bKash collection never completed; deal can still be `active` | Block deal activation unless escrow reaches `held` |
| A4 | **Completed-but-unpaid (legacy/backfill)** | `pending` | Deal flips `completed` while escrow never collected (code only logs a warning) | Reconcile/guard: don't release/complete on a `pending` escrow |
| A5 | **Paid-out-but-not-received** | `paid_out` | Admin marks paid, but the manual bKash B2C transfer actually failed | Confirmation/reconciliation step on payout; record trx + verify |
| A6 | **Abandoned after hold** — provider vanishes post-payment | `held` | No way for buyer to reclaim; refund is admin-only & undefined | Defined refund policy + buyer-initiated refund request |

**Cross-cutting needs for this area:**
- A real **dispute flow**: a button that moves `deals.completion_status → disputed`,
  freezes auto-release, and surfaces the case to admin with both parties' messages.
- **Timeouts** on `pending` completion requests and on uncollected escrow.
- A **refund policy** encoded somewhere (who, when, how much) rather than ad-hoc
  admin action.
- Payout **reconciliation** so `paid_out` means "provider actually received it."

---

## 6. FOCUS B — Dangling providers & job state (medium-high priority)

When Provider A wins, the system never tidies up the losers or the job:

- **Losing interests** stay `accepted` (or `pending`) instead of being closed.
- **Losing conversations** stay `active`; B/C can keep messaging; never notified.
- **Job status** has only `open → assigned → completed`. There is **no
  `closed`/`cancelled`/`reopened`**, so:
  - a fallen-through deal leaves the job stuck `assigned`, filtered off the board,
    un-reopenable;
  - there's no terminal "this job is taken, stop applying" signal to providers.

**What "good" looks like (proposed, not yet built):**
- On deal creation: auto-decline other `pending`/`accepted` interests for the job,
  auto-archive or `closed`-mark their conversations, and notify those providers
  ("This job has been assigned to someone else").
- Add explicit job statuses: `assigned`, `in_progress`, `completed`, `cancelled`,
  and a path back to `open` if a deal collapses.
- Confirm the duplicate-deal guard blocks a *second different provider*, not just a
  race on the same one (`DealsNetworking.swift:215–291`).

---

## 7. Secondary gaps (noted, not prioritized)

- **Provider verification** — `is_service_provider` is self-assigned; no approval,
  no skill/ID check.
- **Silent rejection notifications** — interest-rejected push is best-effort; a
  failure leaves the provider uninformed (`NotificationsNetworking.swift:1217`).
- **Missing payout number** — release snapshots `provider_payout_accounts`; if the
  provider never set a bKash number, admin has nothing to send to.
- **Two-table interest state** — `job_interests.status` and `notifications.status`
  tracked separately; updated together but can drift if one write fails.
- **Admin panel auth** — localhost prototype, no web login yet; service_role key in
  a gitignored `.env` (must stay out of git; rotation advised).

---

## 8. Key files (reference map)

| Concern | File | Symbols |
|---|---|---|
| Interest flow | `NotificationsNetworking.swift` | `showInterestWithMessage`, `createInterestAttempt`, `respondToInterest` |
| Conversation create | migration `20250702000007-add-policies-and-functions.sql` | `handle_interest_acceptance()` trigger |
| Conversations | `MessagesNetworking.swift`, `DatabaseModels.swift:1727` | `setConversationArchived`, `Conversation` |
| Deal offers / deals | `DealsNetworking.swift` | `createDealOffer`, `respondToDealOffer`, `createDealFromAcceptedOffer` |
| Completion | `DealsNetworking.swift`, `CompletionRequestView.swift` | `requestTaskCompletion`, `respondToCompletionRequest` |
| Escrow ledger | `20260607000000-create-escrow-ledger.sql` | `escrow_mark_collected/paid_out/refunded` |
| Pay-to-create | `20260607010000-escrow-pay-to-create.sql` | `escrow_finalize_offer` |
| Payout account | `20260609000000-provider-payout-account.sql` | release trigger, `provider_payout_accounts` |
| Admin panel | `Web/admin-payout-prototype/server.js` | `GET /api/payouts`, `POST /api/payouts/:id/approve` |
| Job filtering | `JobsNetworking.swift:27` | deal-based exclusion |

---

## 9. Open questions to resolve before building fixes

1. **Dispute resolution policy** — who decides, on what evidence, and what are the
   possible outcomes (full refund / partial / release to provider)?
2. **Timeout values** — how many days before a ghosted completion auto-approves (or
   auto-disputes)?
3. **Refund rules** — under what conditions does a buyer get money back, and how
   much (platform fee kept?)?
4. **Job re-opening** — if a deal collapses, should the job return to `open`
   automatically, or require the poster to re-list?
5. **Loser cleanup UX** — auto-decline + notify, or leave conversations open so the
   poster can keep a backup provider warm?
6. **Payout confirmation** — should `paid_out` require the admin to paste a real
   bKash trx id and (eventually) a verified B2C callback?
