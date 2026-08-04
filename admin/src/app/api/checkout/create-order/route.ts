import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { verifyCheckoutToken } from "@/lib/checkout-token";
import { createRazorpayOrder } from "@/lib/razorpay";
import { env } from "@/lib/env";
import { priceWithCoupon } from "@/lib/coupons";
import { notifyN8n } from "@/lib/n8n";

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
  coupon?: string;
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

  // A workshop is priced from the pop-up that advertises it.
  if (payload.kind === "workshop") {
    return await createWorkshopOrder(db, payload.uid, payload.tid, {
      name,
      phone,
      email,
      state,
    });
  }

  // Courses are sold individually, priced from the course row itself.
  if (payload.kind === "course") {
    return await createCourseOrder(
      db,
      payload.uid,
      payload.tid,
      { name, phone, email, state },
      (body.coupon ?? "").trim().toUpperCase() || null,
    );
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
 * Builds a Razorpay order for a workshop seat.
 *
 * No coupon path: workshops are one-off events at a fixed price, and the
 * coupons table is scoped to a course id, so there is nothing here for a
 * code to apply to. The checkout page hides the field for the same
 * reason.
 */
async function createWorkshopOrder(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  db: any,
  userId: string,
  popupId: string,
  billing: Billing,
) {
  const { data: popup } = await db
    .from("app_popups")
    .select("id, title, price_amount, currency, seat_limit, enabled")
    .eq("id", popupId)
    .maybeSingle();

  if (!popup || !popup.enabled) {
    return NextResponse.json(
      { error: "This workshop is no longer open." },
      { status: 404 },
    );
  }
  if (!popup.price_amount || popup.price_amount <= 0) {
    return NextResponse.json(
      { error: "This workshop is not open for paid registration." },
      { status: 400 },
    );
  }

  // Re-checked here and not only on the page: the checkout page can sit
  // open for the whole token's fifteen minutes, and both the last seat
  // and the person's own registration can change underneath it.
  const { data: existing } = await db
    .from("workshop_registrations")
    .select("id")
    .eq("user_id", userId)
    .eq("popup_id", popup.id)
    .eq("status", "paid")
    .maybeSingle();

  if (existing) {
    return NextResponse.json(
      { error: "You are already registered for this workshop." },
      { status: 409 },
    );
  }

  if (popup.seat_limit !== null) {
    const { data: taken } = await db.rpc("workshop_seats_taken", {
      p_popup_id: popup.id,
    });
    if ((taken ?? 0) >= popup.seat_limit) {
      return NextResponse.json(
        { error: "This workshop is full." },
        { status: 409 },
      );
    }
  }

  const title = popup.title ?? "Workshop";

  try {
    const order = await createRazorpayOrder({
      amountRupees: popup.price_amount / 100,
      currency: popup.currency,
      // What razorpay-webhook reads back to know who paid, for what, and
      // how to reach them. popup_id is what makes it a workshop payment
      // rather than a course or a subscription.
      notes: {
        user_id: userId,
        popup_id: popup.id,
        billing_name: billing.name,
        billing_phone: billing.phone,
        billing_email: billing.email,
        billing_state: billing.state,
      },
    });

    // Recorded as pending so an abandoned checkout is still visible; the
    // webhook flips it to paid on the same order id.
    //
    // A plain insert, not an upsert. Both unique indexes on this table
    // are PARTIAL, and Postgres refuses a partial index as an ON CONFLICT
    // target unless the statement repeats its predicate — which
    // PostgREST cannot express. The order id is freshly minted, so there
    // is nothing to conflict with anyway.
    const { error: pendingError } = await db
      .from("workshop_registrations")
      .insert({
        user_id: userId,
        popup_id: popup.id,
        amount: popup.price_amount,
        currency: popup.currency,
        status: "pending",
        razorpay_order_id: order.id,
        billing_name: billing.name,
        billing_phone: billing.phone,
        billing_email: billing.email,
      });

    // Read, not ignored. The identical write on course_purchases had its
    // error dropped, so the pending row it promised was silently never
    // written and abandoned checkouts left no trace at all.
    if (pendingError) {
      console.error("workshop pending row failed:", pendingError.message);
    }

    return NextResponse.json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: env.razorpay().keyId,
      plan_name: title,
      prefill: { name: billing.name, email: billing.email, contact: billing.phone },
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "Could not create order" },
      { status: 502 },
    );
  }
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
  couponCode: string | null,
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
  //
  // Only CURRENT access counts. A revoked enrolment keeps its row (as
  // 'revoked') and a time-limited one keeps its lapsed expires_at, and
  // treating either as ownership would leave the student unable to buy
  // the course back — refused at checkout for access they no longer
  // have.
  const { data: existing } = await db
    .from("course_purchases")
    .select("id")
    .eq("user_id", userId)
    .eq("course_id", courseId)
    .eq("status", "paid")
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
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

  // Apply a coupon if one was entered. Eligibility is re-checked here
  // rather than trusting the preview the browser saw — the price the
  // gateway charges must be derived server-side.
  let payable = course.price_amount;
  let discountAmount = 0;
  let couponId: string | null = null;

  if (couponCode) {
    const { data: couponRow } = await db
      .from("coupons")
      .select(
        "id, code, discount_type, discount_value, course_id, max_redemptions, times_redeemed, starts_at, expires_at, is_active",
      )
      .eq("code", couponCode)
      .maybeSingle();

    const priced = priceWithCoupon(couponRow ?? null, course.id, course.price_amount);
    if (!priced.ok) {
      return NextResponse.json({ error: priced.error }, { status: 400 });
    }

    // Claim the redemption before charging. If two buyers race for the
    // last one, only the winner gets the discount — the loser is told
    // rather than silently charged full price.
    const { data: claimed } = await db.rpc("redeem_coupon", {
      p_coupon_id: priced.result.coupon.id,
    });
    if (claimed !== true) {
      return NextResponse.json(
        { error: "That code has just been fully redeemed." },
        { status: 409 },
      );
    }

    payable = priced.result.finalAmount;
    discountAmount = priced.result.discountAmount;
    couponId = priced.result.coupon.id;
  }

  // A 100%-off code leaves nothing to charge. Grant it directly rather
  // than sending the buyer to a gateway for a ₹0 payment, which Razorpay
  // would reject anyway.
  if (payable === 0) {
    // Plain insert, not an upsert: the "already owned" check above
    // already returned 409, and the paid-row unique index is partial
    // (status = 'paid') so it can't serve as an ON CONFLICT target
    // without repeating its predicate.
    const { error: grantError } = await db.from("course_purchases").insert({
      user_id: userId,
      course_id: course.id,
      amount: 0,
      currency: course.currency,
      status: "paid",
      coupon_id: couponId,
      discount_amount: discountAmount,
      billing_name: billing.name,
    });

    if (grantError) {
      return NextResponse.json({ error: grantError.message }, { status: 500 });
    }

    // Only path where access is granted without razorpay-webhook ever
    // running — there's no payment for it to confirm — so this is the
    // one place that must notify n8n itself, or a 100%-off enrollment
    // would silently never get its confirmation message.
    try {
      let email: string | null = billing.email;
      if (!email) {
        const { data: authUser } = await db.auth.admin.getUserById(userId);
        email = authUser.user?.email ?? null;
      }
      await notifyN8n({
        event: "payment_success",
        user_id: userId,
        email,
        name: billing.name,
        phone: billing.phone,
        state: billing.state,
        plan_name: course.title,
        content_type: "course",
        course_id: course.id,
        coupon_code: couponCode ?? undefined,
        discount_amount: discountAmount ? discountAmount / 100 : undefined,
        amount: 0,
        currency: course.currency,
      });
    } catch (e) {
      console.error("n8n free-course notification failed:", e);
    }

    return NextResponse.json({
      free: true,
      plan_name: course.title,
    });
  }

  try {
    const order = await createRazorpayOrder({
      amountRupees: payable / 100,
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
    //
    // A plain insert, not an upsert. uq_course_purchases_order is
    // PARTIAL (... where razorpay_order_id is not null), and Postgres
    // rejects a partial index as an ON CONFLICT target unless the
    // statement repeats its predicate — which PostgREST's on_conflict
    // parameter cannot express. The upsert that used to be here failed
    // on every call, and because its error was never read, the pending
    // row this comment promises was silently never written. The order id
    // is freshly minted, so there is nothing to conflict with anyway.
    const { error: pendingError } = await db
      .from("course_purchases")
      .insert({
        user_id: userId,
        course_id: course.id,
        amount: payable,
        currency: course.currency,
        status: "pending",
        razorpay_order_id: order.id,
        coupon_id: couponId,
        discount_amount: discountAmount,
        // Kept because it's the only place a buyer's real name is
        // reliably captured — most sign up without ever setting a
        // profile display name, and the completion certificate has to
        // be made out to someone.
        billing_name: billing.name,
      });

    // Non-fatal: the webhook creates the row itself if it isn't there,
    // so a failure here costs visibility of an abandoned checkout, not
    // the purchase.
    if (pendingError) {
      console.error("Could not record pending purchase:", pendingError.message);
    }

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
