import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { verifyCheckoutToken } from "@/lib/checkout-token";
import { priceWithCoupon, type CouponTarget } from "@/lib/coupons";

// Previews what a coupon is worth, so the buyer sees the discounted
// total before committing. Deliberately does NOT redeem it — the
// redemption counter is only claimed at order time, or an abandoned
// checkout would burn a limited code.
//
// Public route, protected by the same signed checkout token as
// create-order rather than by a session.
interface Body {
  token?: string;
  coupon?: string;
}

export async function POST(req: NextRequest) {
  let body: Body;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const code = (body.coupon ?? "").trim().toUpperCase();
  if (!body.token || !code) {
    return NextResponse.json(
      { error: "Enter a coupon code." },
      { status: 400 },
    );
  }

  const payload = verifyCheckoutToken(body.token);
  if (!payload) {
    return NextResponse.json(
      { error: "This link has expired. Please try again from the app." },
      { status: 401 },
    );
  }
  // Workshops are one-off events at a fixed price and coupons have no
  // scope for them, so they are refused here rather than silently
  // ignored on a page that offered the field.
  if (payload.kind === "workshop") {
    return NextResponse.json(
      { error: "Coupons do not apply to session registrations." },
      { status: 400 },
    );
  }

  const db = createAdminClient();

  // Both branches end up with a price in PAISE and a target, so the one
  // pricing function below handles either. subscription_plans stores
  // rupees, which is why it is the only one that multiplies.
  let priceAmount: number;
  let currency: string;
  let target: CouponTarget;

  if (payload.kind === "subscription") {
    const { data: plan } = await db
      .from("subscription_plans")
      .select("id, price, currency")
      .eq("id", payload.tid)
      .eq("is_active", true)
      .maybeSingle();

    if (!plan) {
      return NextResponse.json({ error: "Plan not found" }, { status: 404 });
    }
    priceAmount = Math.round(Number(plan.price) * 100);
    currency = plan.currency;
    target = { kind: "subscription", id: plan.id };
  } else {
    const { data: course } = await db
      .from("courses")
      .select("id, price_amount, currency")
      .eq("id", payload.tid)
      .maybeSingle();

    if (!course) {
      return NextResponse.json({ error: "Course not found" }, { status: 404 });
    }
    priceAmount = course.price_amount;
    currency = course.currency;
    target = { kind: "course", id: course.id };
  }

  const { data: couponRow } = await db
    .from("coupons")
    .select(
      "id, code, discount_type, discount_value, course_id, plan_id, applies_to, max_redemptions, times_redeemed, starts_at, expires_at, is_active",
    )
    .eq("code", code)
    .maybeSingle();

  const priced = priceWithCoupon(couponRow ?? null, target, priceAmount);
  if (!priced.ok) {
    return NextResponse.json({ error: priced.error }, { status: 400 });
  }

  return NextResponse.json({
    code,
    discount_amount: priced.result.discountAmount,
    final_amount: priced.result.finalAmount,
    currency,
  });
}
