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

  // Courses are sold individually, priced from the course row itself.
  if (payload.kind === "course") {
    return await createCourseOrder(db, payload.uid, payload.tid, {
      name,
      phone,
      email,
      state,
    });
  }

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


interface Billing {
  name: string;
  phone: string;
  email: string;
  state: string;
}

/**
 * Builds a Razorpay order for a single course.
 *
 * Seat availability is checked here rather than only in the UI: the
 * checkout page can be left open while the last seat sells, and the seat
 * count is the whole point of a limited cohort.
 */
async function createCourseOrder(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: any,
  userId: string,
  courseId: string,
  billing: Billing,
) {
  const { data: course } = await db
    .from("courses")
    .select("id, title, price_amount, currency, seat_limit, status")
    .eq("id", courseId)
    .maybeSingle();

  if (!course || course.status !== "published") {
    return NextResponse.json({ error: "Course not found" }, { status: 404 });
  }
  if (course.price_amount <= 0) {
    return NextResponse.json(
      { error: "This course is free — no payment is needed." },
      { status: 400 },
    );
  }

  // Already owned: paying twice for the same course is never what the
  // buyer meant, and the unique index would reject the second grant
  // anyway — better to say so before taking money.
  const { data: existing } = await db
    .from("course_purchases")
    .select("id")
    .eq("user_id", userId)
    .eq("course_id", courseId)
    .eq("status", "paid")
    .maybeSingle();

  if (existing) {
    return NextResponse.json(
      { error: "You already have access to this course." },
      { status: 409 },
    );
  }

  if (course.seat_limit !== null) {
    const { count } = await db
      .from("course_purchases")
      .select("id", { count: "exact", head: true })
      .eq("course_id", courseId)
      .eq("status", "paid");

    if ((count ?? 0) >= course.seat_limit) {
      return NextResponse.json(
        { error: "This course is sold out." },
        { status: 409 },
      );
    }
  }

  try {
    const order = await createRazorpayOrder({
      amountRupees: course.price_amount / 100,
      currency: course.currency,
      notes: {
        user_id: userId,
        course_id: course.id,
        billing_name: billing.name,
        billing_phone: billing.phone,
        billing_email: billing.email,
        billing_state: billing.state,
      },
    });

    // Recorded as pending so an abandoned checkout is still visible to
    // the admin; the webhook flips it to paid on the same order id.
    await db.from("course_purchases").upsert(
      {
        user_id: userId,
        course_id: course.id,
        amount: course.price_amount,
        currency: course.currency,
        status: "pending",
        razorpay_order_id: order.id,
      },
      { onConflict: "razorpay_order_id" },
    );

    return NextResponse.json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: env.razorpay().keyId,
      plan_name: course.title,
      prefill: {
        name: billing.name,
        email: billing.email,
        contact: billing.phone,
      },
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Could not create order" },
      { status: 502 },
    );
  }
}
