"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";

// Same conventions as actions/courses.ts: requireAdmin() first,
// service-role client for the mutation, ActionResult return shape,
// revalidatePath before returning.
//
// Certificates were originally gated on completing every lesson AND
// passing every quiz. Quizzes have since been removed from the product,
// so completion is now purely lesson-based — see migration
// 20260801000005.

// ── Certificates ─────────────────────────────────────────────────────────

/**
 * Withdraws a certificate without deleting it.
 *
 * The record has to survive: a certificate number that has been shared
 * publicly must keep resolving, and verify_certificate() reports a
 * revoked one as invalid-and-revoked rather than as never having
 * existed. Deleting would make a withdrawn credential indistinguishable
 * from a forged number.
 */
export async function setCertificateRevoked(
  certificateId: string,
  revoked: boolean,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("certificates")
    .update({ revoked_at: revoked ? new Date().toISOString() : null })
    .eq("id", certificateId);

  if (error) return { ok: false, error: error.message };

  revalidatePath("/certificates");
  return { ok: true };
}

/**
 * Awards a certificate directly, without the learner having completed
 * anything.
 *
 * Separate from issue_certificate(), which learners call and which
 * refuses an unfinished course — that check is the whole meaning of a
 * self-claimed certificate and must not be loosened. This is the
 * deliberate override for the cases the check can't see: someone who did
 * the course offline, a cohort migrated from elsewhere, or progress lost
 * to a bug. Written with the service-role client precisely because it is
 * bypassing a rule.
 *
 * Idempotent by way of the unique (user_id, course_id) constraint: a
 * second award returns the existing certificate rather than minting a
 * duplicate number for the same person and course.
 */
export async function awardCertificate(
  userId: string,
  courseId: string,
): Promise<{ ok: true; number: string } | { ok: false; error: string }> {
  await requireAdmin();
  const db = createAdminClient();

  const { data: existing } = await db
    .from("certificates")
    .select("certificate_number, revoked_at")
    .eq("user_id", userId)
    .eq("course_id", courseId)
    .maybeSingle<{ certificate_number: string; revoked_at: string | null }>();

  if (existing) {
    // A revoked one is reinstated rather than duplicated — awarding again
    // is plainly the intent to restore it.
    if (existing.revoked_at) {
      await db
        .from("certificates")
        .update({ revoked_at: null })
        .eq("user_id", userId)
        .eq("course_id", courseId);
    }
    revalidatePath(`/courses/${courseId}`);
    revalidatePath("/certificates");
    return { ok: true, number: existing.certificate_number };
  }

  const [{ data: course }, { data: profile }] = await Promise.all([
    db.from("courses").select("title").eq("id", courseId)
      .maybeSingle<{ title: string }>(),
    db.from("profiles").select("display_name").eq("id", userId)
      .maybeSingle<{ display_name: string | null }>(),
  ]);

  if (!course) return { ok: false, error: "Course not found." };

  // Same shape issue_certificate() mints, so a manually awarded
  // certificate is indistinguishable to a verifier — which is the point.
  // It is a real credential, not a marked-down one.
  const number =
    `KT-${new Date().getFullYear()}-` +
    crypto.randomUUID().replace(/-/g, "").slice(0, 8).toUpperCase();

  const { error } = await db.from("certificates").insert({
    user_id: userId,
    course_id: courseId,
    certificate_number: number,
    course_title: course.title,
    recipient_name: profile?.display_name ?? null,
  });

  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${courseId}`);
  revalidatePath("/certificates");
  return { ok: true, number };
}

/**
 * Corrects the name printed on a certificate.
 *
 * Needed for two cases the automatic resolution can't cover:
 * certificates issued before billing names were kept, which carry no
 * name at all, and a buyer who typed their name badly at checkout. The
 * course title is NOT editable here — that is a claim about what was
 * earned, and rewriting it would change what the certificate says
 * happened.
 */
export async function updateCertificateRecipient(
  certificateId: string,
  recipientName: string,
): Promise<ActionResult> {
  await requireAdmin();

  const name = recipientName.trim();
  if (!name) return { ok: false, error: "The name can't be empty." };

  const db = createAdminClient();
  const { error } = await db
    .from("certificates")
    .update({ recipient_name: name })
    .eq("id", certificateId);

  if (error) return { ok: false, error: error.message };

  revalidatePath("/certificates");
  return { ok: true };
}
