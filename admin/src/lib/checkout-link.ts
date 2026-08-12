"use client";

import { createClient } from "@/lib/supabase/client";

/** What the storefront can sell, and the body key mint-checkout-token wants. */
export type BuyTarget =
  | { kind: "plan"; id: string }
  | { kind: "course"; id: string }
  | { kind: "session"; id: string };

const BODY_KEY: Record<BuyTarget["kind"], string> = {
  plan: "plan_id",
  course: "course_id",
  session: "live_session_id",
};

/**
 * Mints a signed checkout link for the signed-in buyer, exactly as the
 * mobile app does — same edge function, same token, same
 * `/checkout/[id]?token=` page. The storefront is a second way into that
 * flow, not a second flow.
 *
 * Returns null when nobody is signed in. mint-checkout-token answers 401
 * without a session, and the token carries the buyer's user id, so an
 * account has to exist before there is anything to grant access to.
 */
export async function mintCheckoutPath(
  target: BuyTarget,
): Promise<string | null> {
  const supabase = createClient();

  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session) return null;

  const { data, error } = await supabase.functions.invoke(
    "mint-checkout-token",
    { body: { [BODY_KEY[target.kind]]: target.id } },
  );

  if (error) {
    // Surface what the function said rather than a generic failure. The
    // usual cause is a stale deploy answering "plan_id is required",
    // which is a one-line fix that a swallowed error hides for hours.
    const detail =
      (data as { error?: string } | null)?.error ?? error.message ?? "unknown";
    throw new Error(`Checkout failed: ${detail}`);
  }

  const token = (data as { token?: string } | null)?.token;
  if (!token) throw new Error("Checkout failed: no token returned");

  // src=store tells the checkout page this buyer may not have the app
  // yet, so the confirmation offers the download rather than a deep link
  // into an app that might not be installed. It decides copy only —
  // the token stays the only thing that authorises anything.
  return `/checkout/${target.id}?token=${encodeURIComponent(token)}&src=store`;
}

/** Serialises a target into a URL param, so intent survives a sign-in. */
export function encodeTarget(target: BuyTarget): string {
  return `${target.kind}:${target.id}`;
}

export function decodeTarget(raw: string | null): BuyTarget | null {
  if (!raw) return null;
  const [kind, ...rest] = raw.split(":");
  const id = rest.join(":");
  if (!id) return null;
  if (kind === "plan" || kind === "course" || kind === "session") {
    return { kind, id };
  }
  return null;
}
