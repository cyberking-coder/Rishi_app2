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

/** Course purchases and the subscription go to separate n8n workflows —
 *  see the matching comment in the edge function's copy of this file.
 *  Falls back to the shared webhook if no course-specific one is set. */
function webhookUrlFor(notification: PaymentNotification): string | undefined {
  if (notification.content_type === "course") {
    return process.env.N8N_COURSE_PAYMENT_WEBHOOK_URL ??
      process.env.N8N_PAYMENT_WEBHOOK_URL;
  }
  return process.env.N8N_PAYMENT_WEBHOOK_URL;
}

export async function notifyN8n(notification: PaymentNotification): Promise<void> {
  const webhookUrl = webhookUrlFor(notification);
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
