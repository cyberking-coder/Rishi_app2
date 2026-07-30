// Razorpay webhook signature verification.
//
// Razorpay signs each webhook delivery with HMAC-SHA256 over the EXACT raw
// request body, using a secret set when the webhook is registered in the
// Razorpay dashboard (Settings -> Webhooks). The signature arrives in the
// `X-Razorpay-Signature` header as a hex digest. Verify against the raw
// body text before parsing JSON - re-serializing and re-hashing a parsed
// object is not guaranteed to match the original bytes.

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function verifyRazorpayWebhookSignature(
  rawBody: string,
  signatureHeader: string | null,
): Promise<boolean> {
  if (!signatureHeader) return false;
  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!;
  const expected = await hmacSha256Hex(secret, rawBody);
  // Fixed-length hex digests - safe to compare directly since both sides
  // are always 64 hex chars; a length mismatch just returns false.
  if (expected.length !== signatureHeader.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signatureHeader.charCodeAt(i);
  }
  return diff === 0;
}

/** Fetches an order's `notes` directly from Razorpay's API, rather than
 *  trusting that the resulting payment's own `notes` field mirrors them.
 *  admin/src/lib/razorpay.ts sets notes on the ORDER at creation time, not
 *  on the payment itself (Checkout.js never re-passes them) - fetching the
 *  order is the one unambiguous way to read that metadata back. */
export async function fetchRazorpayOrderNotes(
  orderId: string,
): Promise<Record<string, string>> {
  const keyId = Deno.env.get("RAZORPAY_KEY_ID")!;
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET")!;
  const auth = btoa(`${keyId}:${keySecret}`);

  const res = await fetch(`https://api.razorpay.com/v1/orders/${orderId}`, {
    headers: { Authorization: `Basic ${auth}` },
  });

  if (!res.ok) {
    throw new Error(`Could not fetch Razorpay order ${orderId}: ${res.status}`);
  }

  const order = await res.json();
  return (order.notes as Record<string, string>) ?? {};
}
