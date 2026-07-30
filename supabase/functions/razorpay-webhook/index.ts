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
// "payment.captured", pointing at this function's URL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handlePreflight, jsonResponse } from "../_shared/cors.ts";
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
  notes?: Record<string, string>;
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Signature is computed over the exact raw body — read as text before
  // any JSON parsing.
  const rawBody = await req.text();
  const signature = req.headers.get("X-Razorpay-Signature");
  const validSignature = await verifyRazorpayWebhookSignature(rawBody, signature);
  if (!validSignature) {
    return jsonResponse({ error: "Invalid signature" }, 400);
  }

  let event: { event?: string; payload?: { payment?: { entity?: RazorpayPaymentEntity } } };
  try {
    event = JSON.parse(rawBody);
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  // We only act on payment.captured; acknowledge everything else with 200
  // so Razorpay doesn't retry events we deliberately ignore.
  if (event.event !== "payment.captured") {
    return jsonResponse({ ok: true, ignored: event.event ?? "unknown" });
  }

  const payment = event.payload?.payment?.entity;
  if (!payment?.id) {
    return jsonResponse({ error: "Malformed payment.captured payload" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Idempotency: a redelivered webhook for a payment we've already
  // processed is a no-op, not a second grant.
  const eventKey = `payment.captured:${payment.id}`;
  const { error: dedupeError } = await supabase
    .from("webhook_events")
    .insert({ provider: "razorpay", event_key: eventKey });

  if (dedupeError) {
    // Unique violation == already processed. Any other error is a real
    // failure — return non-200 so Razorpay retries.
    if (dedupeError.code === "23505") {
      return jsonResponse({ ok: true, alreadyProcessed: true });
    }
    return jsonResponse({ error: dedupeError.message }, 500);
  }

  // The order's notes (set at creation time by admin/src/lib/razorpay.ts)
  // are the authoritative source - Checkout.js never re-passes notes when
  // opening the payment modal, so payment.notes below is only a fallback
  // in case Razorpay does mirror them (kept for defense in depth).
  let notes: Record<string, string>;
  try {
    notes = await fetchRazorpayOrderNotes(payment.order_id);
  } catch {
    notes = payment.notes ?? {};
  }
  if (!notes.user_id || !notes.plan_id) {
    notes = payment.notes ?? {};
  }

  const userId = notes.user_id;
  const planId = notes.plan_id;
  if (!userId || !planId) {
    return jsonResponse({ error: "Payment missing user_id/plan_id notes" }, 400);
  }

  const { data: plan, error: planError } = await supabase
    .from("subscription_plans")
    .select("id, billing_interval")
    .eq("id", planId)
    .maybeSingle<{ id: string; billing_interval: string }>();

  if (planError || !plan) {
    return jsonResponse({ error: "Unknown plan on payment notes" }, 404);
  }

  const days = PLAN_INTERVAL_DAYS[plan.billing_interval] ?? 30;
  const now = new Date();
  const periodEnd = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

  const { data: profile } = await supabase
    .from("profiles")
    .select("access_started_at")
    .eq("id", userId)
    .maybeSingle<{ access_started_at: string | null }>();

  const { error: profileError } = await supabase
    .from("profiles")
    .update({
      access_expires_at: periodEnd.toISOString(),
      access_started_at: profile?.access_started_at ?? now.toISOString(),
      subscription_tier: "premium",
    })
    .eq("id", userId);

  if (profileError) {
    return jsonResponse({ error: profileError.message }, 500);
  }

  const { data: existingSub } = await supabase
    .from("subscriptions")
    .select("id")
    .eq("user_id", userId)
    .eq("plan_id", plan.id)
    .in("status", ["trialing", "active"])
    .maybeSingle<{ id: string }>();

  let subscriptionId: string | null = existingSub?.id ?? null;

  if (subscriptionId) {
    await supabase
      .from("subscriptions")
      .update({
        status: "active",
        current_period_start: now.toISOString(),
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
        current_period_start: now.toISOString(),
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

  return jsonResponse({ ok: true });
});
