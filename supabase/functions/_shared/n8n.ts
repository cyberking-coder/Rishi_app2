// Fire-and-forget notification to n8n, which fans out to WhatsApp (via
// Wati) and/or email. This is best-effort - a notification failure must
// never affect payment processing itself, which is why every call site
// wraps this in a try/catch and ignores the error.

export interface PaymentNotification {
  event: "payment_success" | "payment_failed";
  user_id: string;
  email: string | null;
  name: string | null;
  phone: string | null; // E.164-ish, from Razorpay's own contact field
  plan_name: string;
  amount: number; // rupees, not paise
  currency: string;
  reason?: string; // only set for payment_failed
}

export async function notifyN8n(notification: PaymentNotification): Promise<void> {
  const webhookUrl = Deno.env.get("N8N_PAYMENT_WEBHOOK_URL");
  if (!webhookUrl) return; // not configured yet - skip silently

  const res = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(notification),
  });

  if (!res.ok) {
    throw new Error(`n8n webhook returned ${res.status}`);
  }
}
