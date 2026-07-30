import { env } from "./env";

const RAZORPAY_API_BASE = "https://api.razorpay.com/v1";

export interface RazorpayOrder {
  id: string;
  amount: number; // paise
  currency: string;
}

/** Creates a Razorpay order server-side. `notes` are echoed back on the
 *  resulting payment entity in the webhook payload - this is how
 *  razorpay-webhook knows which user/plan a payment is for. */
export async function createRazorpayOrder(args: {
  amountRupees: number;
  currency: string;
  notes: Record<string, string>;
}): Promise<RazorpayOrder> {
  const { keyId, keySecret } = env.razorpay();
  const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");

  const res = await fetch(`${RAZORPAY_API_BASE}/orders`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount: Math.round(args.amountRupees * 100),
      currency: args.currency,
      notes: args.notes,
      payment_capture: 1,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Razorpay order creation failed: ${res.status} ${text}`);
  }

  return (await res.json()) as RazorpayOrder;
}
