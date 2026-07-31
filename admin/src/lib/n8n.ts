import "server-only";

// Mirrors supabase/functions/_shared/n8n.ts — same payload shape, same
// fire-and-forget contract, but callable from the Next.js runtime for the
// one path that never touches the edge function: a course fully covered
// by a coupon. That grant happens directly in create-order (there is no
// payment for razorpay-webhook to confirm), so without this call a
// 100%-off enrollment would silently never notify anyone.

export interface PaymentNotification {
  event: "payment_success" | "payment_failed";
  user_id: string;
  email: string | null;
  name: string | null;
  phone: string | null;
  state: string | null;
  plan_name: string;
  amount: number; // rupees, not paise
  currency: string;
  reason?: string;
  content_type?: "subscription" | "course";
  course_id?: string;
  coupon_code?: string;
  discount_amount?: number; // rupees
}

export async function notifyN8n(notification: PaymentNotification): Promise<void> {
  const webhookUrl = process.env.N8N_PAYMENT_WEBHOOK_URL;
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
