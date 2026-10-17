// ---------------------------------------------------------------------------
// Minimal SSLCommerz v4 hosted-checkout client.
// Docs: https://developer.sslcommerz.com/doc/v4/
//
// All credentials come from environment / Supabase secrets — NEVER hardcode and
// NEVER ship to the client:
//
//   SSLC_BASE_URL      https://sandbox.sslcommerz.com (live: https://securepay.sslcommerz.com)
//   SSLC_STORE_ID
//   SSLC_STORE_PASSWD
//
// Flow: createSession (returns GatewayPageURL) -> [buyer pays on hosted page] ->
//       SSLCommerz POSTs to success/fail/cancel + ipn URLs -> validatePayment
//       (server-side, by val_id) confirms status + amount before fulfilment.
// ---------------------------------------------------------------------------

export interface SslcommerzConfig {
  baseUrl: string;
  storeId: string;
  storePasswd: string;
}

export function loadSslcommerzConfig(): SslcommerzConfig {
  const baseUrl = Deno.env.get("SSLC_BASE_URL");
  const storeId = Deno.env.get("SSLC_STORE_ID");
  const storePasswd = Deno.env.get("SSLC_STORE_PASSWD");
  if (!baseUrl || !storeId || !storePasswd) {
    throw new Error(
      "SSLCommerz not configured: set SSLC_BASE_URL/SSLC_STORE_ID/SSLC_STORE_PASSWD secrets",
    );
  }
  return { baseUrl: baseUrl.replace(/\/$/, ""), storeId, storePasswd };
}

export interface CreateSessionArgs {
  amount: number;
  tranId: string;
  successUrl: string;
  failUrl: string;
  cancelUrl: string;
  ipnUrl: string;
  productName: string;
  customer: {
    name: string;
    email: string;
    phone: string;
    address: string;
    city: string;
    postcode: string;
    country: string;
  };
  /** Echoed back on callbacks/IPN — we carry deal_offer_id here. */
  valueA?: string;
}

export interface CreateSessionResult {
  sessionkey: string;
  gatewayPageURL: string;
}

export async function createSession(
  cfg: SslcommerzConfig,
  args: CreateSessionArgs,
): Promise<CreateSessionResult> {
  const body = new URLSearchParams({
    store_id: cfg.storeId,
    store_passwd: cfg.storePasswd,
    total_amount: args.amount.toFixed(2),
    currency: "BDT",
    tran_id: args.tranId,
    success_url: args.successUrl,
    fail_url: args.failUrl,
    cancel_url: args.cancelUrl,
    ipn_url: args.ipnUrl,
    cus_name: args.customer.name,
    cus_email: args.customer.email,
    cus_add1: args.customer.address,
    cus_city: args.customer.city,
    cus_postcode: args.customer.postcode,
    cus_country: args.customer.country,
    cus_phone: args.customer.phone,
    product_name: args.productName,
    product_category: "service",
    product_profile: "non-physical-goods",
    shipping_method: "NO",
    num_of_item: "1",
    value_a: args.valueA ?? "",
  });

  const res = await fetch(`${cfg.baseUrl}/gwprocess/v4/api.php`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.status !== "SUCCESS" || !data.GatewayPageURL) {
    throw new Error(`SSLCommerz session create failed: ${JSON.stringify(data)}`);
  }
  return { sessionkey: data.sessionkey, gatewayPageURL: data.GatewayPageURL };
}

export interface ValidationResult {
  status?: string; // VALID | VALIDATED | INVALID_TRANSACTION
  tran_id?: string;
  val_id?: string;
  amount?: string;
  currency_type?: string;
  currency_amount?: string;
  bank_tran_id?: string;
  card_type?: string;
  value_a?: string;
  risk_level?: string;
  [k: string]: unknown;
}

// Server-to-server verification of a payment by val_id. The redirect/IPN body
// is NEVER trusted on its own — this call, authenticated with the store
// credentials, is the source of truth.
export async function validatePayment(
  cfg: SslcommerzConfig,
  valId: string,
): Promise<ValidationResult> {
  const qs = new URLSearchParams({
    val_id: valId,
    store_id: cfg.storeId,
    store_passwd: cfg.storePasswd,
    format: "json",
    v: "1",
  });
  const res = await fetch(
    `${cfg.baseUrl}/validator/api/validationserverAPI.php?${qs}`,
  );
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(`SSLCommerz validation failed: ${JSON.stringify(data)}`);
  }
  return data as ValidationResult;
}
