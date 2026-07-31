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

  // Skipping used to be silent, which made "no data arrived in n8n"
  // indistinguishable from "the variable isn't set on this deployment" —
  // the single most likely reason for it. Say which.
  if (!webhookUrl) {
    console.warn(
      `n8n notification skipped: no webhook URL configured for ` +
        `content_type=${notification.content_type ?? "subscription"}. ` +
        `Set N8N_COURSE_PAYMENT_WEBHOOK_URL (or N8N_PAYMENT_WEBHOOK_URL).`,
    );
    return;
  }

  const res = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(notification),
  });

  if (!res.ok) {
    // n8n's body explains itself — a test URL nobody is listening on
    // answers 404 with "the requested webhook is not registered", a
    // completely different fix from a 500.
    const detail = await res.text().catch(() => "");
    throw new Error(
      `n8n webhook returned ${res.status} for ${redact(webhookUrl)}` +
        (detail ? `: ${detail.slice(0, 300)}` : ""),
    );
  }

  console.log(`n8n notified (${res.status}) at ${redact(webhookUrl)}`);
}

/** Host plus path, no query string — enough to tell a test URL from a
 *  production one without copying any token into the logs. */
function redact(url: string): string {
  try {
    const parsed = new URL(url);
    return `${parsed.host}${parsed.pathname}`;
  } catch {
    return "an unparseable URL";
  }
}
