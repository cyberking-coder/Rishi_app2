// Edge Function: razorpay-webhook
//
// Called directly by Razorpay's servers (no user session) whenever a
// payment event happens. This is the ONLY place access is actually
// granted for a paid purchase — the checkout page's client-side "success"
// callback is purely cosmetic (shows a friendly message) and must never be
// trusted to grant anything itself, since it runs in the payer's own
// browser and could be spoofed.
//
// Uses the service-role key (not a forwarded user JWT — there isn't one)
// because granting access means writing profiles/subscriptions/payments,
// which RLS deliberately blocks for anyone but an admin or service_role.
//
// Deployed with: supabase functions deploy razorpay-webhook
// Register in Razorpay Dashboard -> Settings -> Webhooks, active events:
// "payment.captured" AND "payment.failed", pointing at this function's URL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { notifyN8n } from "../_shared/n8n.ts";
import {
  fetchRazorpayOrderNotes,
  verifyRazorpayWebhookSignature,
} from "../_shared/razorpay.ts";

const PLAN_INTERVAL_DAYS: Record<string, number> = {
  weekly: 7,
  monthly: 30,
  yearly: 365,
};

interface RazorpayPaymentEntity {
  id: string;
  order_id: string;
  amount: number; // paise
  currency: string;
  contact?: string; // phone number entered at checkout, e.g. "+919876543210"
  notes?: Record<string, string>;
  error_description?: string; // only present on payment.failed
}

Deno.serve(async (req) => {
  // Deliberately verbose logging throughout: this function is called by
  // Razorpay's servers, not by us, so a silent failure here is invisible
  // (the payment still succeeds on Razorpay's side either way). Every
  // early-exit path logs why, so the Supabase function logs alone are
  // enough to diagnose a non-unlocking payment.
  console.log("[razorpay-webhook] invoked", {
    method: req.method,
    hasSignature: !!req.headers.get("X-Razorpay-Signature"),
  });

  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    console.log("[razorpay-webhook] rejected: not POST");
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Signature is computed over the exact raw body — read as text before
  // any JSON parsing.
  const rawBody = await req.text();
  const signature = req.headers.get("X-Razorpay-Signature");
  const secretConfigured = !!Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
  const validSignature = await verifyRazorpayWebhookSignature(rawBody, signature);
  if (!validSignature) {
    // Most common causes: RAZORPAY_WEBHOOK_SECRET unset/empty, or set to a
    // different value than the one entered in Razorpay's webhook config.
    console.error("[razorpay-webhook] signature verification FAILED", {
      secretConfigured,
      signaturePresent: !!signature,
      bodyLength: rawBody.length,
    });
    return jsonResponse({ error: "Invalid signature" }, 400);
  }

  let event: { event?: string; payload?: { payment?: { entity?: RazorpayPaymentEntity } } };
  try {
    event = JSON.parse(rawBody);
  } catch {
    console.error("[razorpay-webhook] body was not valid JSON");
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const eventType = event.event;
  console.log("[razorpay-webhook] event received:", eventType);

  if (eventType !== "payment.captured" && eventType !== "payment.failed") {
    // Acknowledge everything else with 200 so Razorpay doesn't retry
    // events we deliberately ignore.
    console.log("[razorpay-webhook] ignoring unhandled event type");
    return jsonResponse({ ok: true, ignored: eventType ?? "unknown" });
  }

  const payment = event.payload?.payment?.entity;
  if (!payment?.id) {
    console.error("[razorpay-webhook] payload had no payment entity");
    return jsonResponse({ error: "Malformed payload" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Idempotency: a redelivered webhook for an event we've already
  // processed is a no-op, not a second grant/notification.
  const eventKey = `${eventType}:${payment.id}`;
  const { error: dedupeError } = await supabase
    .from("webhook_events")
    .insert({ provider: "razorpay", event_key: eventKey });

  if (dedupeError) {
    // Unique violation == already processed. Any other error is a real
    // failure — return non-200 so Razorpay retries.
    if (dedupeError.code === "23505") {
      console.log("[razorpay-webhook] already processed, skipping:", eventKey);
      return jsonResponse({ ok: true, alreadyProcessed: true });
    }
    console.error("[razorpay-webhook] dedupe insert failed:", dedupeError.message);
    return jsonResponse({ error: dedupeError.message }, 500);
  }

  // The claim above is staked BEFORE the work it guards, so it has to be
  // given back when that work doesn't finish. Without this, one failed
  // delivery poisoned the payment permanently: the row was already
  // there, so every Razorpay retry took the "already processed" branch
  // and returned 200 without granting anything. A purchase could sit
  // paid-for and locked forever, and the logs showed only a cheerful
  // "skipping" line.
  let response: Response;
  try {
    response = await processEvent(supabase, eventType, payment);
  } catch (e) {
    // A thrown error must not read as a handled outcome — 500 both tells
    // Razorpay to retry and triggers the release below.
    console.error("[razorpay-webhook] unhandled error:", e);
    response = jsonResponse(
      { error: e instanceof Error ? e.message : "Unhandled error" },
      500,
    );
  }

  if (!response.ok) {
    console.error(
      `[razorpay-webhook] handling failed (${response.status}) - releasing ` +
        `${eventKey} so Razorpay's retry can try again`,
    );
    await supabase
      .from("webhook_events")
      .delete()
      .eq("provider", "razorpay")
      .eq("event_key", eventKey);
  }
  return response;
});

/// Everything after the idempotency claim. Split out so a single caller
/// owns whether that claim survives — the release above depends on there
/// being exactly one exit point, which an inline body full of early
/// returns could not offer.
async function processEvent(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  eventType: string,
  // deno-lint-ignore no-explicit-any
  payment: any,
): Promise<Response> {

  // The order's notes (set at creation time by admin/src/lib/razorpay.ts)
  // are the authoritative source - Checkout.js never re-passes notes when
  // opening the payment modal, so payment.notes below is only a fallback
  // in case Razorpay does mirror them (kept for defense in depth).
  let notes: Record<string, string> = {};
  if (payment.order_id) {
    try {
      notes = await fetchRazorpayOrderNotes(payment.order_id);
      console.log("[razorpay-webhook] fetched order notes", {
        orderId: payment.order_id,
        keys: Object.keys(notes),
      });
    } catch (e) {
      console.error("[razorpay-webhook] order fetch failed, falling back to payment.notes:", e);
      notes = payment.notes ?? {};
    }
  } else {
    // No order_id at all. Every purchase THIS app creates goes through the
    // Orders API (admin create-order), so an order-less payment cannot have
    // originated here — there is nothing to fetch. Use whatever notes the
    // payment itself carries, only so the ignore-log below can show what it
    // was. (Previously this called fetchRazorpayOrderNotes(null), which
    // logged a spurious "Could not fetch Razorpay order null: 400".)
    notes = payment.notes ?? {};
  }
  if (
    !notes.user_id ||
    (!notes.plan_id && !notes.course_id && !notes.live_session_id)
  ) {
    // Last resort before deciding it isn't ours: the payment's own notes.
    const paymentNotes = payment.notes ?? {};
    if (paymentNotes.user_id) notes = paymentNotes;
  }

  // Is this payment even ours? A Razorpay webhook is ACCOUNT-WIDE — it fires
  // for every payment on the account, including ones from Payment Pages,
  // Payment Links and Payment Buttons that have nothing to do with this app.
  // Theirs carry a lead-capture form (first_name, city, utm_*, session) and
  // no user_id; those flows do their own fulfilment and we must not touch
  // them. Acknowledge with 200 and ignore — NEVER 400. A 400 tells Razorpay
  // the endpoint is broken, so it retries the same payment forever and then
  // DISABLES the webhook entirely, which stops real app payments unlocking
  // too. That auto-disable is exactly what took the live webhook down.
  const hasTarget = !!(notes.plan_id || notes.course_id || notes.live_session_id);
  if (!notes.user_id || !hasTarget) {
    console.warn(
      "[razorpay-webhook] payment is not from this app — acknowledging and ignoring",
      {
        paymentId: payment.id,
        orderId: payment.order_id ?? null,
        noteKeys: Object.keys(notes),
      },
    );
    return jsonResponse({ ok: true, ignored: "not_an_app_payment" });
  }

  // A seat at a paid live session carries live_session_id. It grants no
  // content access at all — it books a place at an event — so it
  // branches out before any of the access-granting paths below.
  if (notes.live_session_id) {
    return await handleWorkshopRegistration(supabase, {
      eventType,
      payment,
      userId: notes.user_id,
      sessionId: notes.live_session_id,
      billing: {
        email: notes.billing_email ?? null,
        name: notes.billing_name ?? null,
        phone: notes.billing_phone ?? payment.contact ?? null,
        state: notes.billing_state ?? null,
      },
    });
  }

  // Courses are sold individually and carry course_id instead of plan_id.
  // They grant access to that one course rather than touching the
  // account's subscription window, so they branch out before any of the
  // plan lookup below.
  if (notes.course_id) {
    return await handleCoursePurchase(supabase, {
      eventType,
      payment,
      userId: notes.user_id,
      courseId: notes.course_id,
      billing: {
        email: notes.billing_email ?? null,
        name: notes.billing_name ?? null,
        phone: notes.billing_phone ?? payment.contact ?? null,
        state: notes.billing_state ?? null,
      },
    });
  }

  const userId = notes.user_id;
  const planId = notes.plan_id;
  if (!userId || !planId) {
    console.error("[razorpay-webhook] no user_id/plan_id anywhere", {
      orderNoteKeys: Object.keys(notes),
      paymentNoteKeys: Object.keys(payment.notes ?? {}),
    });
    return jsonResponse({ error: "Payment missing user_id/plan_id notes" }, 400);
  }
  console.log("[razorpay-webhook] resolved", { userId, planId });

  const { data: plan, error: planError } = await supabase
    .from("subscription_plans")
    .select("id, name, billing_interval")
    .eq("id", planId)
    .maybeSingle<{ id: string; name: string; billing_interval: string }>();

  if (planError || !plan) {
    return jsonResponse({ error: "Unknown plan on payment notes" }, 404);
  }

  // Look up who to notify - best-effort, missing details just mean a
  // sparser WhatsApp message, never a blocked payment.
  const { data: profile } = await supabase
    .from("profiles")
    .select("display_name, access_started_at, access_expires_at")
    .eq("id", userId)
    .maybeSingle<{
      display_name: string | null;
      access_started_at: string | null;
      access_expires_at: string | null;
    }>();

  // Billing details collected on our own checkout form (see
  // admin/src/app/checkout) are the most reliable source - they're what
  // the user actually typed. Fall back to the account's own details, then
  // to whatever Razorpay captured, so a notification still goes out even
  // if the form data is missing for some reason.
  let email: string | null = notes.billing_email ?? null;
  if (!email) {
    try {
      const { data: authUser } = await supabase.auth.admin.getUserById(userId);
      email = authUser.user?.email ?? null;
    } catch {
      // non-fatal
    }
  }
  const name = notes.billing_name ?? profile?.display_name ?? null;
  const phone = notes.billing_phone ?? payment.contact ?? null;
  const state = notes.billing_state ?? null;

  if (eventType === "payment.failed") {
    // Record the failed attempt for admin visibility, then notify - no
    // access is granted here.
    await supabase.from("payments").upsert(
      {
        user_id: userId,
        amount: payment.amount / 100,
        currency: payment.currency ?? "INR",
        provider: "razorpay",
        provider_payment_id: payment.id,
        status: "failed",
      },
      { onConflict: "provider,provider_payment_id", ignoreDuplicates: true },
    );

    try {
      await notifyN8n({
        event: "payment_failed",
        user_id: userId,
        email,
        name,
        phone,
        state,
        plan_name: plan.name,
        content_type: "subscription",
        amount: payment.amount / 100,
        currency: payment.currency ?? "INR",
        reason: payment.error_description ?? "Payment failed",
      });
    } catch (e) {
      console.error("n8n payment_failed notification failed:", e);
    }

    return jsonResponse({ ok: true });
  }

  // payment.captured — grant access.
  const days = PLAN_INTERVAL_DAYS[plan.billing_interval] ?? 30;
  const now = new Date();

  // Extend from whichever is later: now, or the time they already have.
  //
  // This used to be `now + days` unconditionally, which quietly took
  // money for time the member already owned. Renewing with 20 days left
  // bought 30 days and destroyed 20 — and renewing early is exactly
  // what a reminder email asks people to do, so the members punished
  // hardest were the ones who acted on it.
  //
  // A LAPSED window must not be extended from, or somebody returning
  // after six months away would have their new month land in the past
  // and unlock nothing. max() handles both: an expiry behind us loses
  // to `now`.
  const existingExpiry = profile?.access_expires_at
    ? new Date(profile.access_expires_at)
    : null;
  const extendFrom =
    existingExpiry && existingExpiry.getTime() > now.getTime()
      ? existingExpiry
      : now;
  const periodEnd = new Date(
    extendFrom.getTime() + days * 24 * 60 * 60 * 1000,
  );

  // Unlimited access is `access_expires_at IS NULL` with a start date
  // set — see has_active_access(). Writing a date over that would
  // convert a member an admin gave unlimited access into one whose
  // access ends in a month, and they would have paid for the
  // privilege. If they are already unlimited, the window is left alone
  // and the payment is still recorded below.
  const isUnlimited =
    profile != null &&
    profile.access_expires_at === null &&
    profile.access_started_at !== null;

  const accessPatch: Record<string, string> = {
    access_started_at: profile?.access_started_at ?? now.toISOString(),
    subscription_tier: "premium",
  };
  if (!isUnlimited) {
    accessPatch.access_expires_at = periodEnd.toISOString();
  }

  const { error: profileError } = await supabase
    .from("profiles")
    .update(accessPatch)
    .eq("id", userId);

  if (profileError) {
    console.error("[razorpay-webhook] GRANT FAILED:", profileError.message);
    return jsonResponse({ error: profileError.message }, 500);
  }
  console.log("[razorpay-webhook] access granted", {
    userId,
    // Both, so a support question about "why does my access end then"
    // is answerable from the logs alone.
    extendedFrom: extendFrom.toISOString(),
    accessExpiresAt: isUnlimited ? "unlimited (left as-is)" : periodEnd.toISOString(),
  });

  const { data: existingSub } = await supabase
    .from("subscriptions")
    .select("id")
    .eq("user_id", userId)
    .eq("plan_id", plan.id)
    .in("status", ["trialing", "active"])
    .maybeSingle<{ id: string }>();

  let subscriptionId: string | null = existingSub?.id ?? null;

  // The subscription row records the same window the profile now
  // carries, so `current_period_start` is when the paid period actually
  // begins — not the moment the payment landed. On an early renewal
  // those differ, and Profile → Subscription reads its "Renews /
  // Expires" line straight off this row: a period that disagreed with
  // the access window would have the app telling the member two
  // different dates for the same thing.
  if (subscriptionId) {
    await supabase
      .from("subscriptions")
      .update({
        status: "active",
        current_period_start: extendFrom.toISOString(),
        current_period_end: periodEnd.toISOString(),
      })
      .eq("id", subscriptionId);
  } else {
    const { data: newSub, error: subError } = await supabase
      .from("subscriptions")
      .insert({
        user_id: userId,
        plan_id: plan.id,
        status: "active",
        payment_provider: "razorpay",
        current_period_start: extendFrom.toISOString(),
        current_period_end: periodEnd.toISOString(),
      })
      .select("id")
      .single<{ id: string }>();

    if (subError) {
      return jsonResponse({ error: subError.message }, 500);
    }
    subscriptionId = newSub.id;
  }

  const { error: paymentError } = await supabase
    .from("payments")
    .upsert(
      {
        subscription_id: subscriptionId,
        user_id: userId,
        amount: payment.amount / 100,
        currency: payment.currency ?? "INR",
        provider: "razorpay",
        provider_payment_id: payment.id,
        status: "succeeded",
        paid_at: now.toISOString(),
      },
      { onConflict: "provider,provider_payment_id", ignoreDuplicates: true },
    );

  if (paymentError) {
    return jsonResponse({ error: paymentError.message }, 500);
  }

  try {
    await notifyN8n({
      event: "payment_success",
      user_id: userId,
      email,
      name,
      phone,
      state,
      plan_name: plan.name,
      content_type: "subscription",
      amount: payment.amount / 100,
      currency: payment.currency ?? "INR",
    });
  } catch (e) {
    console.error("n8n payment_success notification failed:", e);
  }

  return jsonResponse({ ok: true });
}


// ── Course purchases ─────────────────────────────────────────────────
//
// A course sale is a one-off, not a renewable window: there is no period
// to extend and no subscription_tier to flip. The purchase row IS the
// entitlement, and has_course_access() reads it directly.
interface CourseBilling {
  email: string | null;
  name: string | null;
  phone: string | null;
  state: string | null;
}

/// Books a workshop seat.
///
/// Deliberately simpler than the course handler, and the simplicity is
/// the point: a registration grants no access to anything. There is no
/// entitlement to reconcile, no expiry to compare, no lapsed row to
/// supersede — only "did this person pay for this seat".
async function handleWorkshopRegistration(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  args: {
    eventType: string;
    // deno-lint-ignore no-explicit-any
    payment: any;
    userId?: string;
    sessionId: string;
    billing: CourseBilling;
  },
): Promise<Response> {
  const { eventType, payment, userId, sessionId, billing } = args;

  if (!userId) {
    console.error("[razorpay-webhook] workshop registration missing user_id");
    return jsonResponse({ error: "Payment missing user_id note" }, 400);
  }

  const { data: session } = await supabase
    .from("live_sessions")
    .select("id, title")
    .eq("id", sessionId)
    .maybeSingle();

  if (!session) {
    console.error("[razorpay-webhook] unknown session on notes", { sessionId });
    return jsonResponse({ error: "Unknown session on payment notes" }, 404);
  }

  const title = session.title ?? "Live session";
  const amountRupees = payment.amount / 100;
  const status = eventType === "payment.failed" ? "failed" : "paid";

  const patch = {
    user_id: userId,
    live_session_id: sessionId,
    amount: payment.amount,
    currency: payment.currency ?? "INR",
    status,
    razorpay_order_id: payment.order_id,
    razorpay_payment_id: payment.id,
    billing_name: billing.name,
    billing_phone: billing.phone,
    billing_email: billing.email,
  };

  // A second payment for a seat they already hold. uq_..._paid would
  // reject the write, the handler would 500, and Razorpay would retry a
  // payment that can never be recorded. Checkout refuses a workshop the
  // person is already registered for, but it cannot close the race —
  // two tabs, or a redelivered older payment, both land here.
  //
  // Recorded as a duplicate so the refund owed is visible rather than
  // the money simply vanishing.
  if (status === "paid") {
    const { data: incumbent } = await supabase
      .from("workshop_registrations")
      .select("id, razorpay_order_id")
      .eq("user_id", userId)
      .eq("live_session_id", sessionId)
      .eq("status", "paid")
      .maybeSingle();

    if (incumbent && incumbent.razorpay_order_id !== payment.order_id) {
      console.error(
        `[razorpay-webhook] DUPLICATE WORKSHOP REGISTRATION - refund owed: ` +
          `user ${userId} already registered for ${sessionId} via order ` +
          `${incumbent.razorpay_order_id}; recording ${payment.id} ` +
          `(order ${payment.order_id}) as duplicate`,
      );

      const duplicatePatch = { ...patch, status: "duplicate" };
      const { data: dupUpdated } = await supabase
        .from("workshop_registrations")
        .update(duplicatePatch)
        .eq("razorpay_order_id", payment.order_id)
        .select("id");

      if (!dupUpdated || dupUpdated.length === 0) {
        await supabase.from("workshop_registrations").insert(duplicatePatch);
      }

      // No notification: "you're registered" is wrong for a payment that
      // registered nobody, and they were told the first time.
      return jsonResponse({ ok: true, duplicate: true });
    }
  }

  // Update-then-insert, never an upsert. Both unique indexes on this
  // table are partial, and Postgres refuses a partial index as an ON
  // CONFLICT target unless the statement repeats its predicate — which
  // PostgREST cannot express. Checkout always writes a pending row, so
  // the UPDATE is the normal path; the INSERT covers a payment whose
  // pending row is missing, so money is never silently unaccounted for.
  const { data: updated, error: updateError } = await supabase
    .from("workshop_registrations")
    .update(patch)
    .eq("razorpay_order_id", payment.order_id)
    .select("id");

  if (updateError) {
    console.error(
      "[razorpay-webhook] WORKSHOP REGISTRATION FAILED:",
      updateError.message,
    );
    return jsonResponse({ error: updateError.message }, 500);
  }

  if (!updated || updated.length === 0) {
    const { error: insertError } = await supabase
      .from("workshop_registrations")
      .insert(patch);

    if (insertError) {
      console.error(
        "[razorpay-webhook] WORKSHOP REGISTRATION FAILED (insert):",
        insertError.message,
      );
      return jsonResponse({ error: insertError.message }, 500);
    }
  }

  console.log("[razorpay-webhook] workshop registration recorded", {
    userId,
    sessionId,
    status,
  });

  let email = billing.email;
  if (!email) {
    try {
      const { data: authUser } = await supabase.auth.admin.getUserById(userId);
      email = authUser.user?.email ?? null;
    } catch {
      // non-fatal
    }
  }

  // Same fill-the-blanks as a course purchase: only ever writes into an
  // empty field, so a name or number the member set themselves is never
  // overwritten by what they typed at checkout.
  if (status === "paid") {
    const { data: profile } = await supabase
      .from("profiles")
      .select("display_name, phone")
      .eq("id", userId)
      .maybeSingle<{ display_name: string | null; phone: string | null }>();

    const profilePatch: Record<string, string> = {};

    if (
      billing.name?.trim() &&
      (!profile?.display_name || profile.display_name.trim() === "")
    ) {
      profilePatch.display_name = billing.name.trim();
    }
    if (
      billing.phone?.trim() &&
      (!profile?.phone || profile.phone.trim() === "")
    ) {
      profilePatch.phone = billing.phone.trim();
    }

    if (Object.keys(profilePatch).length > 0) {
      await supabase.from("profiles").update(profilePatch).eq("id", userId);
    }
  }

  try {
    await notifyN8n({
      event: status === "paid" ? "payment_success" : "payment_failed",
      user_id: userId,
      email,
      name: billing.name,
      phone: billing.phone,
      state: billing.state,
      plan_name: title,
      content_type: "workshop",
      live_session_id: sessionId,
      amount: amountRupees,
      currency: payment.currency ?? "INR",
      reason: status === "failed"
        ? (payment.error_description ?? "Payment failed")
        : undefined,
    });
  } catch (e) {
    console.error("n8n workshop notification failed:", e);
  }

  return jsonResponse({ ok: true });
}

async function handleCoursePurchase(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  args: {
    eventType: string;
    // deno-lint-ignore no-explicit-any
    payment: any;
    userId?: string;
    courseId: string;
    billing: CourseBilling;
  },
): Promise<Response> {
  const { eventType, payment, userId, courseId, billing } = args;

  if (!userId) {
    console.error("[razorpay-webhook] course purchase missing user_id");
    return jsonResponse({ error: "Payment missing user_id note" }, 400);
  }

  const { data: course } = await supabase
    .from("courses")
    .select("id, title")
    .eq("id", courseId)
    .maybeSingle();

  if (!course) {
    console.error("[razorpay-webhook] unknown course on notes", { courseId });
    return jsonResponse({ error: "Unknown course on payment notes" }, 404);
  }

  const amountRupees = payment.amount / 100;
  const status = eventType === "payment.failed" ? "failed" : "paid";

  // Update-then-insert rather than an upsert. The unique index on
  // razorpay_order_id is PARTIAL (... where razorpay_order_id is not
  // null), and Postgres will not accept a partial index as an ON
  // CONFLICT target unless the statement repeats the index predicate —
  // which PostgREST's on_conflict parameter cannot express. An upsert
  // here failed outright, so the payment was never recorded and the
  // course stayed locked.
  //
  // Checkout always creates a pending row for the order, so the UPDATE
  // is the normal path; the INSERT covers a payment whose checkout row
  // is somehow missing, so money is never silently unaccounted for.
  const purchasePatch = {
    user_id: userId,
    course_id: courseId,
    amount: payment.amount,
    currency: payment.currency ?? "INR",
    status,
    razorpay_order_id: payment.order_id,
    razorpay_payment_id: payment.id,
    // The only reliable capture of the buyer's real name: most sign up
    // without setting a profile display name, and the completion
    // certificate has to be made out to someone. create-order writes it
    // to the pending row too; repeating it here covers a payment whose
    // pending row is missing.
    billing_name: billing.name,
  };

  // One paid row per (user, course) is enforced by uq_course_purchases_paid,
  // so a buyer who already owns this course cannot have a second one
  // written — the write fails, the handler 500s, and Razorpay retries a
  // payment that can never be recorded. Checkout refuses a course the
  // buyer already owns, but it cannot close the race: a second tab, a
  // redelivered older payment, or an access grant applied between order
  // creation and capture all land here.
  //
  // Handle it rather than colliding with it. Which of the two cases this
  // is depends on whether the existing row still grants access.
  if (status === "paid") {
    const { data: incumbent } = await supabase
      .from("course_purchases")
      .select("id, razorpay_order_id, expires_at")
      .eq("user_id", userId)
      .eq("course_id", courseId)
      .eq("status", "paid")
      .maybeSingle();

    if (incumbent && incumbent.razorpay_order_id !== payment.order_id) {
      const stillGrantsAccess = incumbent.expires_at === null ||
        new Date(incumbent.expires_at) > new Date();

      if (stillGrantsAccess) {
        // They already have what they just paid for again. Record the
        // payment as a duplicate so a refund is owed visibly rather than
        // the money vanishing, and acknowledge so Razorpay stops
        // retrying something that will never succeed.
        console.error(
          `[razorpay-webhook] DUPLICATE PURCHASE - refund owed: user ` +
            `${userId} already owns course ${courseId} via order ` +
            `${incumbent.razorpay_order_id}; recording ${payment.id} ` +
            `(order ${payment.order_id}) as duplicate`,
        );

        const duplicatePatch = { ...purchasePatch, status: "duplicate" };
        const { data: dupUpdated } = await supabase
          .from("course_purchases")
          .update(duplicatePatch)
          .eq("razorpay_order_id", payment.order_id)
          .select("id");

        if (!dupUpdated || dupUpdated.length === 0) {
          await supabase.from("course_purchases").insert(duplicatePatch);
        }

        // No n8n notification: "you're enrolled" is wrong for a payment
        // that enrolled nobody, and they already got that message the
        // first time.
        return jsonResponse({ ok: true, duplicate: true });
      }

      // The incumbent has lapsed, so this purchase is the buyer getting
      // their access back and must win. Move the old row aside — it no
      // longer grants anything, which is exactly what the admin roster
      // already renders a past expiry as.
      console.log(
        `[razorpay-webhook] superseding lapsed enrolment ${incumbent.id} ` +
          `for user ${userId} on course ${courseId}`,
      );
      await supabase
        .from("course_purchases")
        .update({ status: "revoked", updated_at: new Date().toISOString() })
        .eq("id", incumbent.id);
    }
  }

  const { data: updated, error: updateError } = await supabase
    .from("course_purchases")
    .update(purchasePatch)
    .eq("razorpay_order_id", payment.order_id)
    .select("id");

  if (updateError) {
    console.error("[razorpay-webhook] COURSE GRANT FAILED:", updateError.message);
    return jsonResponse({ error: updateError.message }, 500);
  }

  if (!updated || updated.length === 0) {
    const { error: insertError } = await supabase
      .from("course_purchases")
      .insert(purchasePatch);

    if (insertError) {
      console.error(
        "[razorpay-webhook] COURSE GRANT FAILED (insert):",
        insertError.message,
      );
      return jsonResponse({ error: insertError.message }, 500);
    }
  }
  console.log("[razorpay-webhook] course purchase recorded", {
    userId,
    courseId,
    status,
  });

  // The coupon (if any) was attached to the row at checkout time and
  // survives this upsert untouched (see the comment above the upsert) —
  // read it back so the notification can say what was saved.
  const { data: purchaseRow } = await supabase
    .from("course_purchases")
    .select("coupon_id, discount_amount")
    .eq("razorpay_order_id", payment.order_id)
    .maybeSingle();

  let couponCode: string | undefined;
  if (purchaseRow?.coupon_id) {
    const { data: coupon } = await supabase
      .from("coupons")
      .select("code")
      .eq("id", purchaseRow.coupon_id)
      .maybeSingle();
    couponCode = coupon?.code;
  }

  let email = billing.email;
  if (!email) {
    try {
      const { data: authUser } = await supabase.auth.admin.getUserById(userId);
      email = authUser.user?.email ?? null;
    } catch {
      // non-fatal
    }
  }

  // Fill in what the account is missing from what the buyer just typed at
  // checkout. Only ever fills a blank — a name or number they set
  // themselves is theirs, and this must not overwrite it.
  //
  // The name stops the app greeting people by email address. The phone is
  // what expiry reminders reach them on: checkout has always collected
  // one, handed it to Razorpay and n8n, and then discarded it, so the one
  // message that decides whether a subscription renews had no way to
  // arrive. Same omission the name had, found the same way.
  if (status === "paid") {
    const { data: profile } = await supabase
      .from("profiles")
      .select("display_name, phone")
      .eq("id", userId)
      .maybeSingle<{ display_name: string | null; phone: string | null }>();

    const patch: Record<string, string> = {};

    if (
      billing.name?.trim() &&
      (!profile?.display_name || profile.display_name.trim() === "")
    ) {
      patch.display_name = billing.name.trim();
    }

    if (
      billing.phone?.trim() &&
      (!profile?.phone || profile.phone.trim() === "")
    ) {
      patch.phone = billing.phone.trim();
    }

    if (Object.keys(patch).length > 0) {
      await supabase.from("profiles").update(patch).eq("id", userId);
    }
  }

  try {
    await notifyN8n({
      event: status === "paid" ? "payment_success" : "payment_failed",
      user_id: userId,
      email,
      name: billing.name,
      phone: billing.phone,
      state: billing.state,
      plan_name: course.title,
      content_type: "course",
      course_id: course.id,
      coupon_code: couponCode,
      discount_amount: purchaseRow?.discount_amount
        ? purchaseRow.discount_amount / 100
        : undefined,
      amount: amountRupees,
      currency: payment.currency ?? "INR",
      reason:
        status === "failed"
          ? (payment.error_description ?? "Payment failed")
          : undefined,
    });
  } catch (e) {
    console.error("n8n course notification failed:", e);
  }

  return jsonResponse({ ok: true });
}
