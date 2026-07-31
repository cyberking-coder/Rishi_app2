import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { verifyCheckoutToken } from "@/lib/checkout-token";
import { priceWithCoupon } from "@/lib/coupons";

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
  if (payload.kind !== "course") {
    return NextResponse.json(
      { error: "Coupons apply to courses only." },
      { status: 400 },
    );
  }

  const db = createAdminClient();

  const { data: course } = await db
    .from("courses")
    .select("id, price_amount, currency")
    .eq("id", payload.tid)
    .maybeSingle();

  if (!course) {
    return NextResponse.json({ error: "Course not found" }, { status: 404 });
  }

  const { data: couponRow } = await db
    .from("coupons")
    .select(
      "id, code, discount_type, discount_value, course_id, max_redemptions, times_redeemed, starts_at, expires_at, is_active",
    )
    .eq("code", code)
    .maybeSingle();

  const priced = priceWithCoupon(couponRow ?? null, course.id, course.price_amount);
  if (!priced.ok) {
    return NextResponse.json({ error: priced.error }, { status: 400 });
  }

  return NextResponse.json({
    code,
    discount_amount: priced.result.discountAmount,
    final_amount: priced.result.finalAmount,
    currency: course.currency,
  });
}
