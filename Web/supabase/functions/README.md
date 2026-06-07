# KajHobe Edge Functions — bKash escrow

These functions implement the **collection leg** of deal escrow against the bKash
**Tokenized Checkout sandbox**. The payout leg (`bkash-payout`) is an inert
scaffold until B2C disbursement onboarding exists.

| Function | JWT | Role |
|---|---|---|
| `bkash-collect` | ✅ required | Buyer taps Pay → returns bKash hosted URL |
| `bkash-webhook` | ❌ disabled | bKash redirect → executes payment → escrow `held` |
| `bkash-payout`  | ✅ required | Inert (501) until B2C is live |

## 1. Secrets (sandbox)

> ⚠️ These are **sandbox demo** values, publicly published by bKash/community for
> testing. They are throwaway and must **never** be used in production. Real
> production keys are issued by bKash during merchant onboarding. Secrets live
> only here (Supabase) — never in the iOS/Android app, never committed.

```bash
supabase secrets set \
  BKASH_BASE_URL="https://tokenized.sandbox.bka.sh/v1.2.0-beta/tokenized/checkout" \
  BKASH_APP_KEY="4f6o0cjiki2rfm34kfdadl1eqq" \
  BKASH_APP_SECRET="2is7hdktrekvrbljjh44ll3d9l1dtjo4pasmjvs5vl5qr3fug4b" \
  BKASH_USERNAME="sandboxTokenizedUser02" \
  BKASH_PASSWORD="sandboxTokenizedUser02@12345" \
  APP_DEEPLINK="kajhobe://escrow-callback"
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected
automatically into deployed functions.

## 2. Deploy

```bash
supabase functions deploy bkash-collect
supabase functions deploy bkash-webhook
# bkash-payout is optional (inert); deploy only if you want the 501 stub live.
```

## 3. Sandbox test inputs

- Wallet PIN: `12121`  •  OTP: `123456`
- Insufficient-balance test MSISDN: `01823074817`
- Debit-block test MSISDN: `01823074818`

## 4. End-to-end flow

1. iOS calls `bkash-collect { deal_id }` → `{ bkash_url, payment_id }`.
2. App opens `bkash_url` in `ASWebAuthenticationSession` (callback scheme `kajhobe`).
3. Buyer pays in the sandbox page (PIN/OTP above).
4. bKash redirects to `bkash-webhook`, which executes the payment and calls
   `escrow_mark_collected` → escrow becomes `held`. The webhook 302-redirects to
   `kajhobe://escrow-callback?...`, closing the session.
5. App re-fetches the escrow row and shows **In escrow**.
