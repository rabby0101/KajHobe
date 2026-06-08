// ---------------------------------------------------------------------------
// bkash-webhook  (verify_jwt = false — bKash redirects the buyer's browser here)
//
// bKash calls this callback after the client finishes (or cancels) paying for an
// OFFER, with query params: paymentID, status (success|failure|cancel), and our
// deal_offer_id. On `success` we EXECUTE the payment server-side; on a Completed
// result we call escrow_finalize_offer(), which atomically:
//   accepts the offer -> creates the deal -> marks the deal's escrow `held`.
// So the deal only exists once the money is captured. Finally we redirect the
// browser to the app deep link to close the in-app checkout.
// ---------------------------------------------------------------------------
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { executePayment, grantToken, loadBkashConfig } from "../_shared/bkash.ts";

function redirectToApp(offerId: string, status: string): Response {
  const deeplink = Deno.env.get("APP_DEEPLINK") ?? "kajhobe://escrow-callback";
  const url = `${deeplink}?deal_offer_id=${encodeURIComponent(offerId)}&status=${encodeURIComponent(status)}`;
  return new Response(null, { status: 302, headers: { Location: url } });
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const offerId = url.searchParams.get("deal_offer_id") ?? "";
  const paymentID = url.searchParams.get("paymentID") ?? "";
  const status = (url.searchParams.get("status") ?? "").toLowerCase();

  if (status !== "success" || !paymentID || !offerId) {
    return redirectToApp(offerId, status || "failure");
  }

  try {
    const cfg = loadBkashConfig();
    const token = await grantToken(cfg);
    const result = await executePayment(cfg, token, paymentID);

    if (result.transactionStatus === "Completed") {
      const db = serviceClient();
      const { error } = await db.rpc("escrow_finalize_offer", {
        p_deal_offer_id: offerId,
        p_payment_id: paymentID,
        p_trx_id: result.trxID ?? null,
      });
      if (error) {
        console.error("escrow_finalize_offer failed:", error.message);
        return redirectToApp(offerId, "verify_failed");
      }
      return redirectToApp(offerId, "success");
    }

    console.error("bKash execute not Completed:", JSON.stringify(result));
    return redirectToApp(offerId, "failure");
  } catch (e) {
    console.error("bkash-webhook error:", String(e?.message ?? e));
    return redirectToApp(offerId, "error");
  }
});
