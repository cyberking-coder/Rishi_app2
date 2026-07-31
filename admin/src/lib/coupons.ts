import "server-only";

/** A coupon row, as far as pricing cares about it. */
export interface CouponRow {
  id: string;
  code: string;
  discount_type: "percent" | "flat";
  discount_value: number;
  course_id: string | null;
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

/**
 * Validates a coupon against a course and price, returning what it's
 * worth — or a reason it doesn't apply.
 *
 * This only *checks* eligibility; it never marks the code as used. The
 * redemption counter is bumped atomically by the redeem_coupon()
 * function at order time, because two checkouts can pass this check
 * simultaneously and only one may take the last redemption.
 */
export function priceWithCoupon(
  coupon: CouponRow | null,
  courseId: string,
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
  if (coupon.course_id !== null && coupon.course_id !== courseId) {
    return { ok: false, error: "That code doesn't apply to this course." };
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
