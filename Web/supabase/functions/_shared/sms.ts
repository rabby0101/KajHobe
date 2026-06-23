// ---------------------------------------------------------------------------
// Pluggable SMS sender for the Bangladesh market.
//
// The OTP flow (send-sms-otp) only ever calls `sendSms(phone, message)`. WHICH
// gateway actually delivers it is decided here from env, so we can wire a real
// BD gateway (bulksmsbd / SSL Wireless / MiMSMS) later without touching the hook.
//
// Until SMS_GATEWAY_URL is set, we run in "stub" mode: the message + OTP are
// logged (visible via `supabase functions logs send-sms-otp`) so the end-to-end
// signup/verify flow is fully testable in dev before any paid gateway exists.
// ---------------------------------------------------------------------------

export interface SmsResult {
  ok: boolean;
  provider: string;
  detail?: string;
}

// Normalise to the form most BD gateways expect: 8801XXXXXXXXX (country code,
// no +). Accepts 01XXXXXXXXX, 8801..., or +8801... .
export function toBdMsisdn(phone: string): string {
  const digits = (phone ?? "").replace(/[^\d]/g, "");
  if (digits.startsWith("880")) return digits;
  if (digits.startsWith("0")) return "88" + digits;
  return digits;
}

export async function sendSms(phone: string, message: string): Promise<SmsResult> {
  const gatewayUrl = Deno.env.get("SMS_GATEWAY_URL");
  const apiKey = Deno.env.get("SMS_API_KEY");
  const senderId = Deno.env.get("SMS_SENDER_ID") ?? "";
  const msisdn = toBdMsisdn(phone);

  // --- Dev/stub mode -------------------------------------------------------
  if (!gatewayUrl || !apiKey) {
    console.log(`[sms:stub] -> ${msisdn}: ${message}`);
    return { ok: true, provider: "stub", detail: "logged (no gateway configured)" };
  }

  // --- Generic BD gateway (HTTP GET/POST with query params) ----------------
  // Defaults match the common bulksmsbd-style API:
  //   {url}?api_key=..&type=text&senderid=..&number=..&message=..
  // Override the param names via env if your gateway differs.
  const pApi = Deno.env.get("SMS_PARAM_API_KEY") ?? "api_key";
  const pNumber = Deno.env.get("SMS_PARAM_NUMBER") ?? "number";
  const pMessage = Deno.env.get("SMS_PARAM_MESSAGE") ?? "message";
  const pSender = Deno.env.get("SMS_PARAM_SENDER") ?? "senderid";

  const params = new URLSearchParams();
  params.set(pApi, apiKey);
  params.set(pNumber, msisdn);
  params.set(pMessage, message);
  if (senderId) params.set(pSender, senderId);
  const extraType = Deno.env.get("SMS_PARAM_TYPE");
  if (extraType) params.set("type", extraType);

  try {
    const method = (Deno.env.get("SMS_HTTP_METHOD") ?? "GET").toUpperCase();
    const res = method === "POST"
      ? await fetch(gatewayUrl, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: params.toString(),
        })
      : await fetch(`${gatewayUrl}?${params.toString()}`);

    const body = await res.text();
    if (!res.ok) {
      console.error(`[sms] gateway HTTP ${res.status}: ${body}`);
      return { ok: false, provider: "gateway", detail: `HTTP ${res.status}` };
    }
    return { ok: true, provider: "gateway", detail: body.slice(0, 200) };
  } catch (e) {
    console.error("[sms] gateway error:", String((e as Error)?.message ?? e));
    return { ok: false, provider: "gateway", detail: String((e as Error)?.message ?? e) };
  }
}
