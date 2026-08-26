"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";

export interface SubscriptionPlan {
  id: string;
  name: string;
  description: string | null;
  /** RUPEES, and the only price in this system that is not paise —
   *  see the note in savePlan(). */
  price: number;
  currency: string;
  billing_interval: "weekly" | "monthly" | "yearly";
  is_active: boolean;
  created_at: string;
}

export interface PlanInput {
  id?: string;
  name: string;
  description?: string | null;
  /** Rupees, as typed. */
  price: number;
  billingInterval: "weekly" | "monthly" | "yearly";
  isActive: boolean;
}

export async function listPlans(): Promise<SubscriptionPlan[]> {
  await requireAdmin();
  const db = createAdminClient();
  const { data, error } = await db
    .from("subscription_plans")
    .select("id, name, description, price, currency, billing_interval, is_active, created_at")
    .order("price", { ascending: true })
    .returns<SubscriptionPlan[]>();

  // F-5 from the 25 August audit: `const { data }` discarded `error`, so
  // a failed query rendered as "no plans yet" — on the page an admin uses
  // to check what the app is charging. An empty list and a broken query
  // must not look alike, least of all here.
  if (error) throw new Error(`Could not load plans: ${error.message}`);
  return data ?? [];
}

/**
 * Creates or updates a plan.
 *
 * `price` is stored in RUPEES here, not paise. That is inconsistent with
 * courses and sessions and it is deliberate: subscription_plans has held
 * rupees since the first migration, the checkout reads it that way, and
 * changing the unit under a live pricing table is a data migration with
 * a real chance of charging somebody a hundred times too much. The
 * boundaries convert instead — see the coupon path in create-order.
 */
export async function savePlan(input: PlanInput): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const name = input.name.trim();
  if (!name) return { ok: false, error: "Give the plan a name." };

  if (!Number.isFinite(input.price) || input.price <= 0) {
    return { ok: false, error: "The price must be more than ₹0." };
  }
  // Razorpay refuses anything under ₹1, and a plan priced below it would
  // fail at the gateway with an error the buyer cannot act on.
  if (input.price < 1) {
    return { ok: false, error: "The price must be at least ₹1." };
  }

  const row = {
    name,
    description: input.description?.trim() || null,
    // Two decimal places, matching numeric(10,2). Rounded here so what
    // is stored is exactly what the gateway will be asked for.
    price: Math.round(input.price * 100) / 100,
    currency: "INR",
    billing_interval: input.billingInterval,
    is_active: input.isActive,
  };

  const { error } = input.id
    ? await db.from("subscription_plans").update(row).eq("id", input.id)
    : await db.from("subscription_plans").insert(row);

  if (error) {
    return {
      ok: false,
      error: error.code === "23505"
        ? "A plan with that name already exists."
        : error.message,
    };
  }

  revalidatePath("/plans");
  return { ok: true };
}

/**
 * Retires a plan.
 *
 * Deactivates rather than deletes, always. `subscriptions.plan_id` is a
 * plain foreign key with no cascade, so a delete would either fail
 * outright or — worse, if that constraint is ever relaxed — orphan the
 * record of what somebody actually bought. A price that is no longer
 * sold still has to be readable on the receipt of everyone who paid it.
 */
export async function setPlanActive(args: {
  planId: string;
  isActive: boolean;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("subscription_plans")
    .update({ is_active: args.isActive })
    .eq("id", args.planId);

  if (error) return { ok: false, error: error.message };

  revalidatePath("/plans");
  return { ok: true };
}
