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

/** Course purchases and the subscription go to separate n8n workflows —
 *  they're different products with different messages, and a course
 *  workflow can ship and iterate without touching the subscription one
 *  (which isn't in active use right now). Falls back to the shared
 *  N8N_PAYMENT_WEBHOOK_URL if no course-specific one is set, so this
 *  degrades gracefully rather than going silent mid-rollout. */
function webhookUrlFor(notification: PaymentNotification): string | undefined {
  if (notification.content_type === "course") {
    return Deno.env.get("N8N_COURSE_PAYMENT_WEBHOOK_URL") ??
      Deno.env.get("N8N_PAYMENT_WEBHOOK_URL");
  }
  return Deno.env.get("N8N_PAYMENT_WEBHOOK_URL");
}

export async function notifyN8n(notification: PaymentNotification): Promise<void> {
  const webhookUrl = webhookUrlFor(notification);

  // Skipping used to be silent, which made "no data arrived in n8n"
  // indistinguishable from "the variable isn't set on this function" —
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
    // The body carries n8n's own explanation — a test URL that nobody is
    // listening on answers 404 with "the requested webhook is not
    // registered", which is a completely different fix from a 500.
    const detail = await res.text().catch(() => "");
    throw new Error(
      `n8n webhook returned ${res.status} for ${redact(webhookUrl)}` +
        (detail ? `: ${detail.slice(0, 300)}` : ""),
    );
  }

  console.log(`n8n notified (${res.status}) at ${redact(webhookUrl)}`);
}

/// Host plus path, no query string — enough to tell a test URL from a
/// production one, or one workflow from another, without copying any
/// token in the query into the logs.
function redact(url: string): string {
  try {
    const parsed = new URL(url);
    return `${parsed.host}${parsed.pathname}`;
  } catch {
    return "an unparseable URL";
  }
}
