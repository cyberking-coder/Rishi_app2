"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";

export interface CreateCouponInput {
  code: string;
  description?: string;
  discountType: "percent" | "flat";
  /** Percent: 1-100. Flat: rupees (converted to paise here). */
  discountValue: number;
  /** What the code is for. 'course' with no courseId means every course;
   *  'subscription' with no planId means every plan; 'any' means both. */
  appliesTo?: "course" | "subscription" | "any";
  /** Only with appliesTo 'course'. Omit for every course. */
  courseId?: string;
  /** Only with appliesTo 'subscription'. Omit for every plan. */
  planId?: string;
  maxRedemptions?: number | null;
  expiresAt?: string | null;
}

export async function createCoupon(
  input: CreateCouponInput,
): Promise<ActionResult> {
  const admin = await requireAdmin();
  const db = createAdminClient();

  const code = input.code.trim().toUpperCase();
  if (!/^[A-Z0-9_-]{3,32}$/.test(code)) {
    return {
      ok: false,
      error: "Codes are 3–32 characters: letters, numbers, dashes only.",
    };
  }

  if (input.discountType === "percent") {
    if (!Number.isInteger(input.discountValue) ||
        input.discountValue < 1 ||
        input.discountValue > 100) {
      return { ok: false, error: "A percentage must be between 1 and 100." };
    }
  } else if (!(input.discountValue > 0)) {
    return { ok: false, error: "A flat discount must be more than ₹0." };
  }

  const { error } = await db.from("coupons").insert({
    code,
    description: input.description?.trim() || null,
    discount_type: input.discountType,
    // Percent stays a percent; flat converts rupees to paise so it
    // compares directly against course price_amount.
    discount_value:
      input.discountType === "percent"
        ? input.discountValue
        : Math.round(input.discountValue * 100),
    applies_to: input.appliesTo ?? "course",
    // The database refuses a target that contradicts the scope, so these
    // are cleared rather than trusted: a form that once had a course
    // selected and was then switched to the membership must not carry
    // the stale id through.
    course_id: input.appliesTo === "course" ? input.courseId || null : null,
    plan_id: input.appliesTo === "subscription" ? input.planId || null : null,
    max_redemptions: input.maxRedemptions ?? null,
    expires_at: input.expiresAt || null,
    created_by: admin.id,
  });

  if (error) {
    return {
      ok: false,
      error: error.code === "23505"
        ? "That code already exists."
        : error.message,
    };
  }

  revalidatePath("/coupons");
  return { ok: true };
}

export async function setCouponActive(args: {
  couponId: string;
  isActive: boolean;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("coupons")
    .update({ is_active: args.isActive })
    .eq("id", args.couponId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/coupons");
  return { ok: true };
}

export async function deleteCoupon(couponId: string): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db.from("coupons").delete().eq("id", couponId);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/coupons");
  return { ok: true };
}
