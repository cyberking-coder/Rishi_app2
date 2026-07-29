import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { verifyCheckoutToken } from "@/lib/checkout-token";
import { createRazorpayOrder } from "@/lib/razorpay";
import { env } from "@/lib/env";

// Public route - protected by the checkout token, not Supabase auth (the
// caller is an anonymous browser tab opened from the mobile app, not a
// logged-in admin). Only ever trusts the plan id embedded in the signed
// token, never one passed directly in the request body.
export async function POST(req: NextRequest) {
  let body: { token?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!body.token) {
    return NextResponse.json({ error: "token is required" }, { status: 400 });
  }

  const payload = verifyCheckoutToken(body.token);
  if (!payload) {
    return NextResponse.json(
      { error: "This link has expired. Please try again from the app." },
      { status: 401 },
    );
  }

  const db = createAdminClient();
  const { data: plan, error } = await db
    .from("subscription_plans")
    .select("id, name, price, currency")
    .eq("id", payload.tid)
    .eq("is_active", true)
    .maybeSingle<{ id: string; name: string; price: number; currency: string }>();

  if (error || !plan) {
    return NextResponse.json({ error: "Plan not found" }, { status: 404 });
  }

  try {
    const order = await createRazorpayOrder({
      amountRupees: plan.price,
      currency: plan.currency,
      notes: { user_id: payload.uid, plan_id: plan.id },
    });

    return NextResponse.json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: env.razorpay().keyId,
      plan_name: plan.name,
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Could not create order" },
      { status: 502 },
    );
  }
}
