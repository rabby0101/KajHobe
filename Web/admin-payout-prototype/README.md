# KajHobe — Admin Payout Panel (prototype)

A minimal **localhost-only** admin page to settle provider payouts. When a deal
completes, its escrow moves `held → released` automatically. This panel lists
every `released` escrow awaiting payout, shows **who to pay**, the provider's
**private bKash number** (to verify manually), and the amount, with an
**Approve** button that records the payout (`released → paid_out`).

> **Prototype, no login.** The Supabase **service role key** lives in `.env`
> (server-side) and bypasses RLS so the panel can read the private bKash number.
> Run it only on `localhost`. Never deploy it publicly or commit `.env`.

## Why a Node server (not a static page)?
The service role key must never reach a browser. `server.js` holds it and
exposes only two narrow endpoints (`GET /api/payouts`, `POST
/api/payouts/:id/approve`); the page (`public/index.html`) talks to those.

## Current payout model
bKash B2C / Instant Payout (Disbursement) is **not yet enabled** (no sandbox,
requires merchant onboarding). So payout is a **manual** step: the admin sends
money in the bKash merchant app, then records it here. When B2C goes live, the
Approve action can be extended to call the `bkash-payout` Edge Function to move
money automatically — see `Web/supabase/functions/bkash-payout/index.ts`.

## Setup
```bash
cd Web/admin-payout-prototype
cp .env.example .env        # then paste your service_role key into .env
npm install
npm start                   # http://localhost:4000
```
Get the `service_role` secret from: Supabase Dashboard → Project Settings → API.

## Admin workflow
1. Open `http://localhost:4000` — see deals awaiting payout.
2. Verify the provider's bKash number (the panel flags if none is set, or if the
   live number differs from the one snapshotted at release time).
3. Send the money manually in the bKash merchant app.
4. Paste the bKash transaction ID and click **Approve · Mark Paid Out**.

The escrow flips to `paid_out` (recording `payout_trx_id`, `paid_out_at`, and an
`escrow_events` audit row) and the deal drops off the list.

## Backend dependencies
- `provider_payout_accounts` table + `escrow_service_mark_paid_out()` RPC, from
  migration `Web/supabase/migrations/20260609000000-provider-payout-account.sql`.
- Escrow ledger from `20260607000000-create-escrow-ledger.sql`.
