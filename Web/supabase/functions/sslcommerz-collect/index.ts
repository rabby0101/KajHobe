// ---------------------------------------------------------------------------
// sslcommerz-collect  (verify_jwt = true)
//
// Called when the client taps "Accept & Pay" on a provider's deal OFFER. Creates
// an SSLCommerz v4 hosted-checkout session for the offer amount and returns the
// GatewayPageURL. NO deal/escrow is created here — the deal only comes into
// existence after a validated payment, in `sslcommerz-webhook` ->
// escrow_finalize_offer.
//
// Auth: the JWT must belong to the offer's CLIENT, and the offer must still be
// 'pending' (not already accepted/rejected).
//
// Body: { deal_offer_id: string, platform?: "web" | "mobile" }
// The platform is threaded into the callback URLs so the webhook knows whether
// to bounce the browser back to the app deep link or to the web return page.
// ---------------------------------------------------------------------------
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { serviceClient, userFromRequest } from "../_shared/supabase.ts";
import { createSession, loadSslcommerzConfig } from "../_shared/sslcommerz.ts";

// SSLCommerz enforces a 10.00–500,000.00 BDT range per transaction.
const MIN_AMOUNT_BDT = 10;
const MAX_AMOUNT_BDT = 500_000;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  try {
    const user = await userFromRequest(req);
    if (!user) return jsonResponse({ error: "unauthorized" }, 401);

    const { deal_offer_id, platform } = await req.json().catch(() => ({}));
    if (!deal_offer_id) return jsonResponse({ error: "deal_offer_id required" }, 400);
    const plat = platform === "web" ? "web" : "mobile";

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
    if (offer.amount < MIN_AMOUNT_BDT || offer.amount > MAX_AMOUNT_BDT) {
      return jsonResponse(
        { error: `amount must be between ৳${MIN_AMOUNT_BDT} and ৳${MAX_AMOUNT_BDT}` },
        422,
      );
    }

    // Buyer details for SSLCommerz's mandatory cus_* fields. It requires them
    // but does not verify — fall back to placeholders where the profile is thin.
    const { data: profile } = await db
      .from("profiles")
      .select("full_name, email, phone, location")
      .eq("id", user.id)
      .maybeSingle();

    const cfg = loadSslcommerzConfig();

    // Unique per payment ATTEMPT: a cancelled/failed checkout must get a fresh
    // tran_id on retry. deal_offer_id travels in the URLs + value_a instead.
    const tranId = `OFFER-${String(deal_offer_id).slice(0, 8)}-${Date.now().toString(36)}`;

    const webhookBase =
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/sslcommerz-webhook` +
      `?deal_offer_id=${encodeURIComponent(deal_offer_id)}&platform=${plat}`;

    const session = await createSession(cfg, {
      amount: offer.amount,
      tranId,
      successUrl: webhookBase,
      failUrl: webhookBase,
      cancelUrl: webhookBase,
      // IPN is server-to-server (no browser to redirect) — omit platform.
      ipnUrl:
        `${Deno.env.get("SUPABASE_URL")}/functions/v1/sslcommerz-webhook` +
        `?deal_offer_id=${encodeURIComponent(deal_offer_id)}&ipn=1`,
      productName: `KajHobe deal offer ${String(deal_offer_id).slice(0, 8)}`,
      customer: {
        name: profile?.full_name || "KajHobe Customer",
        email: profile?.email || "customer@kajhobe.bd",
        phone: profile?.phone || "01700000000",
        address: profile?.location || "Dhaka",
        city: "Dhaka",
        postcode: "1000",
        country: "Bangladesh",
      },
      valueA: String(deal_offer_id),
    });

    return jsonResponse({ checkout_url: session.gatewayPageURL, tran_id: tranId });
  } catch (e) {
    return jsonResponse({ error: String(e?.message ?? e) }, 500);
  }
});
