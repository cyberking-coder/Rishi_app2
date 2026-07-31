// Fire-and-forget notification to n8n, which fans out to WhatsApp (via
// Wati) and/or email. This is best-effort - a notification failure must
// never affect payment processing itself, which is why every call site
// wraps this in a try/catch and ignores the error.

export interface PaymentNotification {
  event: "payment_success" | "payment_failed";
  user_id: string;
  email: string | null;
  name: string | null;
  /** Collected on our own checkout form; falls back to Razorpay's contact. */
  phone: string | null;
  state: string | null;
  /** Subscription plan name, or the course title for a course purchase. */
  plan_name: string;
  amount: number; // rupees, not paise
  currency: string;
  reason?: string; // only set for payment_failed
  /** Lets the n8n workflow pick a different WhatsApp/email template for a
   *  course purchase vs the recurring subscription — "you're in Rishi
   *  Mode" reads wrong on a one-off course sale, and vice versa. */
  content_type?: "subscription" | "course";
  /** Only set for content_type: "course" — lets the message deep-link
   *  straight to the course instead of the generic app link. */
  course_id?: string;
  /** Set when a coupon was applied, so the message can say what was saved. */
  coupon_code?: string;
  discount_amount?: number; // rupees
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
