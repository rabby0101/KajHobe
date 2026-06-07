// ---------------------------------------------------------------------------
// bkash-payout  (verify_jwt = true) — SCAFFOLD / INERT
//
// The "release to provider" leg. bKash B2C / Instant Payout (Disbursement) has
// NO open sandbox and requires a vetted merchant + disbursement agreement, which
// is not yet in place. Until then, payout is handled as a MANUAL admin action
// (escrow_mark_paid_out RPC) and this function intentionally does nothing.
//
// When B2C onboarding is complete, implement here:
//   1. auth: require admin (is_admin)
//   2. load escrow row, require state = 'released'
//   3. grant token -> call bKash B2C disbursement to provider_msisdn for
//      provider_amount
//   4. on success: escrow_mark_paid_out(escrow_id, notes, trxID)
// ---------------------------------------------------------------------------
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return jsonResponse({
    error: "not_configured",
    message:
      "bKash B2C disbursement is not enabled. Provider payout is currently a manual admin step (escrow_mark_paid_out).",
  }, 501);
});
