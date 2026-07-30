import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { verifyCheckoutToken } from "@/lib/checkout-token";
import { createRazorpayOrder } from "@/lib/razorpay";
import { env } from "@/lib/env";

// Public route - protected by the checkout token, not Supabase auth (the
// caller is an anonymous browser tab opened from the mobile app, not a
// logged-in admin). Only ever trusts the plan id embedded in the signed
// token, never one passed directly in the request body.
interface CreateOrderBody {
  token?: string;
  name?: string;
  phone?: string;
  email?: string;
  state?: string;
}

export async function POST(req: NextRequest) {
  let body: CreateOrderBody;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!body.token) {
    return NextResponse.json({ error: "token is required" }, { status: 400 });
  }

  // Billing details are collected on our page (not inside Razorpay's
  // modal) so we reliably have a phone number for the WhatsApp
  // confirmation - Razorpay's own `contact` field isn't guaranteed to
  // reach us in a usable shape. Re-validated here because client-side
  // validation is a convenience, not a control.
  const name = (body.name ?? "").trim();
  const phone = (body.phone ?? "").replace(/\s|-/g, "").trim();
  const email = (body.email ?? "").trim();
  const state = (body.state ?? "").trim();

  if (!name || !phone || !email || !state) {
    return NextResponse.json(
      { error: "Please fill in all billing details." },
      { status: 400 },
    );
  }
  if (!/^\+?[0-9]{10,15}$/.test(phone)) {
    return NextResponse.json(
      { error: "Please enter a valid phone number." },
      { status: 400 },
    );
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return NextResponse.json(
      { error: "Please enter a valid email address." },
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
    // These notes are what razorpay-webhook reads back (by fetching the
    // order) to know who paid and how to reach them.
    const order = await createRazorpayOrder({
      amountRupees: plan.price,
      currency: plan.currency,
      notes: {
        user_id: payload.uid,
        plan_id: plan.id,
        billing_name: name,
        billing_phone: phone,
        billing_email: email,
        billing_state: state,
      },
    });

    return NextResponse.json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: env.razorpay().keyId,
      plan_name: plan.name,
      prefill: { name, email, contact: phone },
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Could not create order" },
      { status: 502 },
    );
  }
}
