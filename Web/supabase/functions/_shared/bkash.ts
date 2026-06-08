// ---------------------------------------------------------------------------
// Minimal bKash Tokenized Checkout client (SANDBOX).
//
// All credentials come from environment / Supabase secrets — NEVER hardcode and
// NEVER ship to the client. Sandbox demo values (publicly published by bKash &
// the community) are fine for dev but must not be reused in production:
//
//   BKASH_BASE_URL   e.g. https://tokenized.sandbox.bka.sh/v1.2.0-beta/tokenized/checkout
//   BKASH_APP_KEY
//   BKASH_APP_SECRET
//   BKASH_USERNAME
//   BKASH_PASSWORD
//
// Flow: grantToken -> createPayment (returns bkashURL) -> [user pays] ->
//       executePayment (server-side, returns trxID + transactionStatus).
// ---------------------------------------------------------------------------

export interface BkashConfig {
  baseUrl: string;
  appKey: string;
  appSecret: string;
  username: string;
  password: string;
}

export function loadBkashConfig(): BkashConfig {
  const baseUrl = Deno.env.get("BKASH_BASE_URL");
  const appKey = Deno.env.get("BKASH_APP_KEY");
  const appSecret = Deno.env.get("BKASH_APP_SECRET");
  const username = Deno.env.get("BKASH_USERNAME");
  const password = Deno.env.get("BKASH_PASSWORD");
  if (!baseUrl || !appKey || !appSecret || !username || !password) {
    throw new Error(
      "bKash not configured: set BKASH_BASE_URL/APP_KEY/APP_SECRET/USERNAME/PASSWORD secrets",
    );
  }
  return { baseUrl, appKey, appSecret, username, password };
}

export async function grantToken(cfg: BkashConfig): Promise<string> {
  const res = await fetch(`${cfg.baseUrl}/token/grant`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "username": cfg.username,
      "password": cfg.password,
    },
    body: JSON.stringify({ app_key: cfg.appKey, app_secret: cfg.appSecret }),
  });
  const data = await res.json();
  if (!res.ok || !data.id_token) {
    throw new Error(`bKash token grant failed: ${JSON.stringify(data)}`);
  }
  return data.id_token as string;
}

export interface CreatePaymentResult {
  paymentID: string;
  bkashURL: string;
  statusCode?: string;
  statusMessage?: string;
  [k: string]: unknown;
}

export async function createPayment(
  cfg: BkashConfig,
  idToken: string,
  args: {
    amount: number;
    callbackURL: string;
    payerReference: string;
    merchantInvoiceNumber: string;
  },
): Promise<CreatePaymentResult> {
  const res = await fetch(`${cfg.baseUrl}/create`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": idToken,
      "X-APP-Key": cfg.appKey,
    },
    body: JSON.stringify({
      mode: "0011", // checkout (URL) mode
      payerReference: args.payerReference,
      callbackURL: args.callbackURL,
      amount: String(args.amount),
      currency: "BDT",
      intent: "sale",
      merchantInvoiceNumber: args.merchantInvoiceNumber,
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.paymentID || !data.bkashURL) {
    throw new Error(`bKash create failed: ${JSON.stringify(data)}`);
  }
  return data as CreatePaymentResult;
}

export interface ExecutePaymentResult {
  paymentID: string;
  trxID?: string;
  transactionStatus?: string; // "Completed" on success
  statusCode?: string;
  statusMessage?: string;
  [k: string]: unknown;
}

export async function executePayment(
  cfg: BkashConfig,
  idToken: string,
  paymentID: string,
): Promise<ExecutePaymentResult> {
  const res = await fetch(`${cfg.baseUrl}/execute`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": idToken,
      "X-APP-Key": cfg.appKey,
    },
    body: JSON.stringify({ paymentID }),
  });
  const data = await res.json();
  if (!res.ok) {
    throw new Error(`bKash execute failed: ${JSON.stringify(data)}`);
  }
  return data as ExecutePaymentResult;
}
