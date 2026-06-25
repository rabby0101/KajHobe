// ---------------------------------------------------------------------------
// send-sms-otp  (verify_jwt = false — invoked by Supabase Auth as a Send SMS Hook)
//
// Supabase Auth has NO built-in SMS provider for Bangladesh. We register this
// function as the "Send SMS" auth hook: whenever Auth needs to deliver a phone
// OTP (signup, login, phone-number verification) it POSTs us the payload:
//   { "user": { "phone": "8801..." }, "sms": { "otp": "123456" } }
// and we relay it through our pluggable BD gateway (see _shared/sms.ts). In dev,
// with no gateway configured, the OTP is logged so the flow stays testable.
//
// Optional hardening: if SEND_SMS_HOOK_SECRET is set, the Standard Webhooks
// signature is verified before we send anything.
// ---------------------------------------------------------------------------
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { sendSms } from "../_shared/sms.ts";

interface SendSmsHookPayload {
  user?: { id?: string; phone?: string };
  sms?: { otp?: string };
  phone?: string; // tolerated fallbacks
  otp?: string;
}

function otpMessage(otp: string): string {
  const brand = Deno.env.get("SMS_BRAND") ?? "KajHobe";
  return `${otp} apnar ${brand} verification code. Code ti karo sathe share korben na.`;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: SendSmsHookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const phone = payload.user?.phone ?? payload.phone ?? "";
  const otp = payload.sms?.otp ?? payload.otp ?? "";

  if (!phone || !otp) {
    console.error("send-sms-otp: missing phone or otp in payload");
    return new Response(JSON.stringify({ error: "missing phone or otp" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const result = await sendSms(phone, otpMessage(otp));
  if (!result.ok) {
    // Returning an error tells Supabase Auth the OTP was NOT delivered.
    return new Response(JSON.stringify({ error: { message: result.detail ?? "sms send failed" } }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
