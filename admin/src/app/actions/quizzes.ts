"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import type { ActionResult } from "./users";

// Same conventions as actions/courses.ts: requireAdmin() first,
// service-role client for the mutation, ActionResult return shape,
// revalidatePath before returning.

// ── Quizzes ──────────────────────────────────────────────────────────────

export interface CreateQuizInput {
  courseId: string;
  /** Set for a checkpoint inside one lesson; omit for the course's final
   *  assessment. The database enforces that exactly one of these is set. */
  lessonId?: string;
  title: string;
  description?: string;
  passPercent: number;
  /** null/undefined = unlimited retakes. */
  maxAttempts?: number | null;
}

export async function createQuiz(
  input: CreateQuizInput,
): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
  await requireAdmin();
  const db = createAdminClient();

  const { data, error } = await db
    .from("quizzes")
    .insert({
      // A lesson quiz carries lesson_id ONLY — chk_quiz_owner rejects a
      // row with both, and the lesson already implies its course.
      course_id: input.lessonId ? null : input.courseId,
      lesson_id: input.lessonId ?? null,
      title: input.title.trim(),
      description: input.description?.trim() || null,
      pass_percent: input.passPercent,
      max_attempts: input.maxAttempts ?? null,
    })
    .select("id")
    .single<{ id: string }>();

  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${input.courseId}`);
  return { ok: true, id: data.id };
}

export async function updateQuiz(
  quizId: string,
  courseId: string,
  patch: {
    title?: string;
    description?: string | null;
    passPercent?: number;
    maxAttempts?: number | null;
  },
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("quizzes")
    .update({
      ...(patch.title !== undefined ? { title: patch.title.trim() } : {}),
      ...(patch.description !== undefined
        ? { description: patch.description?.trim() || null }
        : {}),
      ...(patch.passPercent !== undefined
        ? { pass_percent: patch.passPercent }
        : {}),
      ...(patch.maxAttempts !== undefined
        ? { max_attempts: patch.maxAttempts }
        : {}),
    })
    .eq("id", quizId);

  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${courseId}`);
  return { ok: true };
}

export async function deleteQuiz(
  quizId: string,
  courseId: string,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  // Questions, options and attempts cascade. Attempts going with it is
  // intentional — a score against a quiz that no longer exists can't be
  // interpreted, and leaving orphans would make course_completion_state
  // count passes for a quiz nobody can take.
  const { error } = await db.from("quizzes").delete().eq("id", quizId);
  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${courseId}`);
  return { ok: true };
}

// ── Questions ────────────────────────────────────────────────────────────

export interface QuestionOptionInput {
  label: string;
  isCorrect: boolean;
}

export interface SaveQuestionInput {
  quizId: string;
  courseId: string;
  /** Omit to create; supply to replace an existing question's content. */
  questionId?: string;
  prompt: string;
  explanation?: string;
  options: QuestionOptionInput[];
}

/**
 * Creates or rewrites one question together with its options.
 *
 * Options are replaced wholesale rather than diffed. Editing a question
 * means its options are being reconsidered as a set, and a diff would
 * have to decide what a "changed" option means for attempts that already
 * reference the old row — replacing makes that explicit instead.
 */
export async function saveQuestion(
  input: SaveQuestionInput,
): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
  await requireAdmin();

  const prompt = input.prompt.trim();
  if (!prompt) return { ok: false, error: "The question can't be empty." };

  const options = input.options
    .map((o) => ({ ...o, label: o.label.trim() }))
    .filter((o) => o.label.length > 0);

  if (options.length < 2) {
    return { ok: false, error: "A question needs at least two options." };
  }
  // Refused rather than silently scored as unanswerable: submit_quiz_attempt
  // marks every answer wrong when no option is correct, so a question saved
  // in this state would fail every learner with no way to tell why.
  if (!options.some((o) => o.isCorrect)) {
    return { ok: false, error: "Mark one option as the correct answer." };
  }
  if (options.filter((o) => o.isCorrect).length > 1) {
    return {
      ok: false,
      error: "Only one option can be correct — these are single-answer questions.",
    };
  }

  const db = createAdminClient();
  let questionId = input.questionId;

  if (questionId) {
    const { error } = await db
      .from("quiz_questions")
      .update({ prompt, explanation: input.explanation?.trim() || null })
      .eq("id", questionId);
    if (error) return { ok: false, error: error.message };

    const { error: clearError } = await db
      .from("quiz_options")
      .delete()
      .eq("question_id", questionId);
    if (clearError) return { ok: false, error: clearError.message };
  } else {
    // Appended after whatever is already there. Read-then-write rather
    // than a max() in SQL, which PostgREST can't express — a race here
    // would only mean two questions sharing a position, which sorts
    // stably on created_at anyway.
    const { count } = await db
      .from("quiz_questions")
      .select("id", { count: "exact", head: true })
      .eq("quiz_id", input.quizId);

    const { data, error } = await db
      .from("quiz_questions")
      .insert({
        quiz_id: input.quizId,
        prompt,
        explanation: input.explanation?.trim() || null,
        position: count ?? 0,
      })
      .select("id")
      .single<{ id: string }>();

    if (error) return { ok: false, error: error.message };
    questionId = data.id;
  }

  const { error: optionsError } = await db.from("quiz_options").insert(
    options.map((o, i) => ({
      question_id: questionId,
      label: o.label,
      is_correct: o.isCorrect,
      position: i,
    })),
  );
  if (optionsError) return { ok: false, error: optionsError.message };

  revalidatePath(`/courses/${input.courseId}`);
  return { ok: true, id: questionId };
}

export async function deleteQuestion(
  questionId: string,
  courseId: string,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("quiz_questions")
    .delete()
    .eq("id", questionId);
  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${courseId}`);
  return { ok: true };
}

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
