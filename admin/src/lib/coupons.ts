import "server-only";

/** A coupon row, as far as pricing cares about it. */
export interface CouponRow {
  id: string;
  code: string;
  discount_type: "percent" | "flat";
  discount_value: number;
  course_id: string | null;
  plan_id: string | null;
  applies_to: "course" | "subscription" | "any";
  max_redemptions: number | null;
  times_redeemed: number;
  starts_at: string | null;
  expires_at: string | null;
  is_active: boolean;
}

export interface PricedCoupon {
  coupon: CouponRow;
  /** Paise taken off. Never more than the price itself. */
  discountAmount: number;
  /** Paise actually payable after the discount. */
  finalAmount: number;
}

/** What a coupon is being applied to. Both ids are the thing's own id;
 *  `kind` is what decides which of the coupon's scopes has to match. */
export type CouponTarget =
  | { kind: "course"; id: string }
  | { kind: "subscription"; id: string };

/**
 * Validates a coupon against what is being bought and its price,
 * returning what the code is worth — or a reason it doesn't apply.
 *
 * `priceAmount` is always PAISE, whatever the thing is. Courses and
 * sessions store paise already; subscription_plans stores rupees, so its
 * caller converts before getting here. Mixing the two units in this
 * function is how a ₹100-off code takes ₹1 off a membership.
 *
 * This only *checks* eligibility; it never marks the code as used. The
 * redemption counter is bumped atomically by the redeem_coupon()
 * function at order time, because two checkouts can pass this check
 * simultaneously and only one may take the last redemption.
 */
export function priceWithCoupon(
  coupon: CouponRow | null,
  target: CouponTarget,
  priceAmount: number,
): { ok: true; result: PricedCoupon } | { ok: false; error: string } {
  if (!coupon) return { ok: false, error: "That code isn't valid." };
  if (!coupon.is_active) return { ok: false, error: "That code is no longer active." };

  const now = Date.now();
  if (coupon.starts_at && new Date(coupon.starts_at).getTime() > now) {
    return { ok: false, error: "That code isn't active yet." };
  }
  if (coupon.expires_at && new Date(coupon.expires_at).getTime() <= now) {
    return { ok: false, error: "That code has expired." };
  }
  if (
    coupon.max_redemptions !== null &&
    coupon.times_redeemed >= coupon.max_redemptions
  ) {
    return { ok: false, error: "That code has been fully redeemed." };
  }
  // Scope first, then the specific item. Checked in that order so the
  // message names the real problem: a course code entered against the
  // membership should say so, not "doesn't apply to this course".
  if (coupon.applies_to !== "any" && coupon.applies_to !== target.kind) {
    return {
      ok: false,
      error: target.kind === "subscription"
        ? "That code is for courses, not the membership."
        : "That code is for the membership, not for courses.",
    };
  }

  if (target.kind === "course") {
    if (coupon.course_id !== null && coupon.course_id !== target.id) {
      return { ok: false, error: "That code doesn't apply to this course." };
    }
  } else if (coupon.plan_id !== null && coupon.plan_id !== target.id) {
    return { ok: false, error: "That code doesn't apply to this plan." };
  }

  const raw =
    coupon.discount_type === "percent"
      ? Math.round((priceAmount * coupon.discount_value) / 100)
      : coupon.discount_value;

  // A discount can wipe out the price but never invert it.
  const discountAmount = Math.min(raw, priceAmount);
  const finalAmount = priceAmount - discountAmount;

  // Razorpay rejects orders under ₹1. Rather than fail at the gateway
  // with an opaque error, refuse here with something the buyer can act
  // on — and note a 100%-off code is a "free course", not a sale.
  if (finalAmount > 0 && finalAmount < 100) {
    return {
      ok: false,
      error: "That code would bring the total below the ₹1 minimum.",
    };
  }

  return { ok: true, result: { coupon, discountAmount, finalAmount } };
}
