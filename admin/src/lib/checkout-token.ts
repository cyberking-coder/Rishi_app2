import { createHmac, timingSafeEqual } from "node:crypto";
import { env } from "./env";

// Verifies tokens minted by supabase/functions/_shared/checkout_token.ts.
// MUST stay byte-for-byte compatible with that file's format:
//   base64url(JSON payload) + "." + base64url(HMAC-SHA256 signature)

export type CheckoutKind = "subscription" | "course";

export interface CheckoutTokenPayload {
  uid: string;
  kind: CheckoutKind;
  tid: string;
  exp: number;
}

export function verifyCheckoutToken(token: string): CheckoutTokenPayload | null {
  const parts = token.split(".");
  if (parts.length !== 2) return null;
  const [payloadPart, signaturePart] = parts;

  let payloadBytes: Buffer;
  let signatureBytes: Buffer;
  try {
    payloadBytes = Buffer.from(payloadPart, "base64url");
    signatureBytes = Buffer.from(signaturePart, "base64url");
  } catch {
    return null;
  }

  const expected = createHmac("sha256", env.checkoutTokenSecret())
    .update(payloadBytes)
    .digest();

  if (
    expected.length !== signatureBytes.length ||
    !timingSafeEqual(expected, signatureBytes)
  ) {
    return null;
  }

  let payload: CheckoutTokenPayload;
  try {
    payload = JSON.parse(payloadBytes.toString("utf-8"));
  } catch {
    return null;
  }

  if (
    (payload.kind !== "subscription" && payload.kind !== "course") ||
    !payload.uid ||
    !payload.tid
  ) {
    return null;
  }
  if (payload.exp * 1000 < Date.now()) {
    return null; // expired
  }

  return payload;
}
