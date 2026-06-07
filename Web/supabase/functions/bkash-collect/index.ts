// ---------------------------------------------------------------------------
// bkash-collect  (verify_jwt = true)
//
// Called when the client taps "Accept & Pay" on a provider's deal OFFER. Creates
// a bKash Tokenized Checkout (sandbox) payment for the offer amount and returns
// the hosted bKash URL. NO deal/escrow is created here — the deal only comes into
// existence after a confirmed capture, in `bkash-webhook` -> escrow_finalize_offer.
//
// Auth: the JWT must belong to the offer's CLIENT, and the offer must still be
// 'pending' (not already accepted/rejected).
// ---------------------------------------------------------------------------
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { serviceClient, userFromRequest } from "../_shared/supabase.ts";
import { createPayment, grantToken, loadBkashConfig } from "../_shared/bkash.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  try {
    const user = await userFromRequest(req);
    if (!user) return jsonResponse({ error: "unauthorized" }, 401);

    const { deal_offer_id } = await req.json().catch(() => ({}));
    if (!deal_offer_id) return jsonResponse({ error: "deal_offer_id required" }, 400);

    const db = serviceClient();
    const { data: offer, error } = await db
      .from("deal_offers")
      .select("id, client_id, amount, status")
      .eq("id", deal_offer_id)
      .single();
    if (error || !offer) return jsonResponse({ error: "offer_not_found" }, 404);

    if (offer.client_id !== user.id) {
      return jsonResponse({ error: "only the client can accept and pay this offer" }, 403);
    }
    if (offer.status !== "pending") {
      return jsonResponse({ error: `offer already ${offer.status}` }, 409);
    }

    const cfg = loadBkashConfig();
    const token = await grantToken(cfg);

    const callbackURL =
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/bkash-webhook?deal_offer_id=${deal_offer_id}`;

    const payment = await createPayment(cfg, token, {
      amount: offer.amount,
      callbackURL,
      payerReference: String(offer.client_id).slice(0, 8),
      merchantInvoiceNumber: `OFFER-${String(deal_offer_id).slice(0, 8)}`,
    });

    return jsonResponse({ bkash_url: payment.bkashURL, payment_id: payment.paymentID });
  } catch (e) {
    return jsonResponse({ error: String(e?.message ?? e) }, 500);
  }
});
