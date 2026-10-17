// ---------------------------------------------------------------------------
// sslcommerz-webhook  (verify_jwt = false — SSLCommerz POSTs here with no JWT)
//
// Receives BOTH kinds of SSLCommerz callbacks for an OFFER payment:
//   • browser redirects to success/fail/cancel URLs (query has ?platform=web|mobile)
//   • server-to-server IPN (query has ?ipn=1)
// Both arrive as POSTs with a form-encoded body: status, tran_id, val_id, …
//
// The body is NEVER trusted on its own. On status=VALID we call the validation
// API with val_id (authenticated by store credentials) and require VALID/
// VALIDATED plus an exact amount+currency match against the offer. Only then
// do we call escrow_finalize_offer(), which atomically:
//   accepts the offer -> creates the deal -> marks the deal's escrow `held`.
// The RPC is idempotent, so the redirect and the IPN can both fire safely.
//
// Response: IPN gets JSON; browser redirects get a 302 — to the app deep link
// (mobile) or to WEB_RETURN_URL (web).
// ---------------------------------------------------------------------------
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { loadSslcommerzConfig, validatePayment } from "../_shared/sslcommerz.ts";

function redirectResponse(platform: string, offerId: string, status: string): Response {
  let base: string;
  if (platform === "web") {
    base = Deno.env.get("WEB_RETURN_URL") ?? "https://www.kajhobe.bd/escrow-return";
  } else {
    base = Deno.env.get("APP_DEEPLINK") ?? "kajhobe://escrow-callback";
  }
  const url = `${base}?deal_offer_id=${encodeURIComponent(offerId)}&status=${encodeURIComponent(status)}`;
  return new Response(null, { status: 302, headers: { Location: url } });
}

// IPN callers just need an acknowledgement; browsers need the redirect.
function respond(isIpn: boolean, platform: string, offerId: string, status: string): Response {
  if (isIpn) {
    return new Response(JSON.stringify({ ok: true, status }), {
      headers: { "Content-Type": "application/json" },
    });
  }
  return redirectResponse(platform, offerId, status);
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const isIpn = url.searchParams.get("ipn") === "1";
  const platform = url.searchParams.get("platform") ?? "mobile";

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    form = new FormData();
  }
  const field = (name: string) => {
    const v = form.get(name);
    return typeof v === "string" ? v : "";
  };

  // deal_offer_id: query param first, value_a echo as fallback.
  const offerId = url.searchParams.get("deal_offer_id") || field("value_a");
  const gwStatus = field("status").toUpperCase(); // VALID | FAILED | CANCELLED | …
  const valId = field("val_id");

  if (!offerId) {
    console.error("sslcommerz-webhook: missing deal_offer_id", { gwStatus });
    return respond(isIpn, platform, "", "error");
  }

  if (gwStatus === "CANCELLED") return respond(isIpn, platform, offerId, "cancel");
  if (gwStatus !== "VALID" || !valId) {
    return respond(isIpn, platform, offerId, "failure");
  }

  try {
    const cfg = loadSslcommerzConfig();
    const validation = await validatePayment(cfg, valId);

    const validated =
      validation.status === "VALID" || validation.status === "VALIDATED";
    if (!validated) {
      console.error("sslcommerz validation not VALID:", JSON.stringify(validation));
      return respond(isIpn, platform, offerId, "verify_failed");
    }

    const db = serviceClient();
    const { data: offer, error: offerErr } = await db
      .from("deal_offers")
      .select("id, amount")
      .eq("id", offerId)
      .single();
    if (offerErr || !offer) {
      console.error("sslcommerz-webhook: offer not found:", offerId);
      return respond(isIpn, platform, offerId, "verify_failed");
    }

    // The validated amount/currency must match the offer exactly — a tampered
    // success redirect or a partial payment must never fund the escrow.
    const paidAmount = Number(validation.currency_amount ?? validation.amount);
    if (
      validation.currency_type !== "BDT" ||
      !Number.isFinite(paidAmount) ||
      Math.abs(paidAmount - Number(offer.amount)) > 0.009
    ) {
      console.error("sslcommerz amount/currency mismatch:", {
        expected: offer.amount,
        got: validation.amount,
        currency: validation.currency_type,
      });
      return respond(isIpn, platform, offerId, "verify_failed");
    }

    const { error } = await db.rpc("escrow_finalize_offer", {
      p_deal_offer_id: offerId,
      p_payment_id: valId,
      p_trx_id: validation.bank_tran_id ?? null,
    });
    if (error) {
      console.error("escrow_finalize_offer failed:", error.message);
      return respond(isIpn, platform, offerId, "verify_failed");
    }
    return respond(isIpn, platform, offerId, "success");
  } catch (e) {
    console.error("sslcommerz-webhook error:", String(e?.message ?? e));
    return respond(isIpn, platform, offerId, "error");
  }
});
