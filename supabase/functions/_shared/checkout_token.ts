// Short-lived signed token identifying a user + purchase target to the
// external web checkout page, without requiring a second login there.
//
// Format: base64url(JSON payload) + "." + base64url(HMAC-SHA256 signature)
// over the payload bytes. Verified independently (same algorithm, same
// shared secret) by the admin Next.js app's checkout route — see
// admin/src/lib/checkout-token.ts, which MUST stay byte-for-byte
// compatible with this implementation.
//
// CHECKOUT_TOKEN_SECRET lives only in Supabase function secrets and the
// admin app's environment - never in source.

export interface CheckoutTokenPayload {
  uid: string; // purchasing user's id
  kind: "subscription"; // only kind supported so far
  tid: string; // target id - a subscription_plans.id
  exp: number; // unix seconds
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function hmacKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("CHECKOUT_TOKEN_SECRET")!;
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

export async function mintCheckoutToken(
  payload: Omit<CheckoutTokenPayload, "exp">,
  ttlSeconds: number,
): Promise<string> {
  const full: CheckoutTokenPayload = {
    ...payload,
    exp: Math.floor(Date.now() / 1000) + ttlSeconds,
  };
  const payloadBytes = new TextEncoder().encode(JSON.stringify(full));
  const signature = await crypto.subtle.sign("HMAC", await hmacKey(), payloadBytes);
  return `${base64UrlEncode(payloadBytes)}.${base64UrlEncode(new Uint8Array(signature))}`;
}
