"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { slugify } from "@/lib/utils";
import type { CourseStatus, LessonType } from "@/lib/types";
import type { ActionResult } from "./users";

// Same conventions as actions/content.ts: requireAdmin() first,
// service-role client for the mutation, ActionResult return shape,
// revalidatePath before returning.

// ── Courses ──────────────────────────────────────────────────────────────

export interface CreateCourseInput {
  title: string;
  description?: string;
  isPremium: boolean;
  categoryId?: string;
}

export async function createCourse(
  input: CreateCourseInput,
): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
  const admin = await requireAdmin();
  const db = createAdminClient();

  const { data, error } = await db
    .from("courses")
    .insert({
      title: input.title,
      slug: `${slugify(input.title)}-${Date.now().toString(36)}`,
      description: input.description ?? null,
      is_premium: input.isPremium,
      category_id: input.categoryId || null,
      status: "draft" as CourseStatus,
      created_by: admin.id,
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    return { ok: false, error: error?.message ?? "Could not create course" };
  }

  revalidatePath("/courses");
  return { ok: true, id: data.id };
}

export async function updateCourse(args: {
  courseId: string;
  title?: string;
  description?: string | null;
  categoryId?: string | null;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const patch: Record<string, unknown> = {};
  if (args.title !== undefined) patch.title = args.title;
  if (args.description !== undefined) patch.description = args.description;
  if (args.categoryId !== undefined) patch.category_id = args.categoryId || null;

  const { error } = await db.from("courses").update(patch).eq("id", args.courseId);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/courses");
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function setCourseStatus(args: {
  courseId: string;
  status: CourseStatus;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("courses")
    .update({ status: args.status })
    .eq("id", args.courseId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/courses");
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function setCoursePremium(args: {
  courseId: string;
  isPremium: boolean;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("courses")
    .update({ is_premium: args.isPremium })
    .eq("id", args.courseId);

  if (error) return { ok: false, error: error.message };
  revalidatePath("/courses");
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function deleteCourse(courseId: string): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  // Modules and lessons cascade; the audios/videos the lessons referenced
  // are left alone (lessons hold a reference, not ownership).
  const { error } = await db.from("courses").delete().eq("id", courseId);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/courses");
  return { ok: true };
}

// ── Modules ──────────────────────────────────────────────────────────────

export async function createModule(args: {
  courseId: string;
  title: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { data: last } = await db
    .from("course_modules")
    .select("position")
    .eq("course_id", args.courseId)
    .order("position", { ascending: false })
    .limit(1)
    .maybeSingle<{ position: number }>();

  const { error } = await db.from("course_modules").insert({
    course_id: args.courseId,
    title: args.title,
    position: (last?.position ?? -1) + 1,
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function renameModule(args: {
  moduleId: string;
  courseId: string;
  title: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("course_modules")
    .update({ title: args.title })
    .eq("id", args.moduleId);

  if (error) return { ok: false, error: error.message };
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function deleteModule(args: {
  moduleId: string;
  courseId: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("course_modules")
    .delete()
    .eq("id", args.moduleId);

  if (error) return { ok: false, error: error.message };
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

/** Swaps a module with its neighbour. Positions carry no unique
 *  constraint (see the LMS migration header), so a plain two-row swap is
 *  safe without a transaction or deferred constraint. */
export async function moveModule(args: {
  moduleId: string;
  courseId: string;
  direction: "up" | "down";
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { data: modules } = await db
    .from("course_modules")
    .select("id, position")
    .eq("course_id", args.courseId)
    .order("position", { ascending: true })
    .order("created_at", { ascending: true })
    .returns<{ id: string; position: number }[]>();

  if (!modules) return { ok: false, error: "Could not load modules" };

  const index = modules.findIndex((m) => m.id === args.moduleId);
  const swapWith = args.direction === "up" ? index - 1 : index + 1;
  if (index < 0 || swapWith < 0 || swapWith >= modules.length) {
    return { ok: true }; // already at the end — nothing to do
  }

  // Rewrite positions from the reordered array rather than swapping two
  // values, so any pre-existing duplicate/gap positions get normalized.
  const reordered = [...modules];
  [reordered[index], reordered[swapWith]] = [reordered[swapWith], reordered[index]];

  for (let i = 0; i < reordered.length; i++) {
    const { error } = await db
      .from("course_modules")
      .update({ position: i })
      .eq("id", reordered[i].id);
    if (error) return { ok: false, error: error.message };
  }

  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

// ── Lessons ──────────────────────────────────────────────────────────────

export interface CreateLessonInput {
  moduleId: string;
  courseId: string;
  title: string;
  lessonType: LessonType;
  audioId?: string;
  videoId?: string;
  bodyMarkdown?: string;
}

export async function createLesson(
  input: CreateLessonInput,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  if (input.lessonType === "text" && !input.bodyMarkdown?.trim()) {
    return { ok: false, error: "A text lesson needs some content." };
  }
  if (input.lessonType === "audio" && !input.audioId) {
    return { ok: false, error: "Pick an audio for this lesson." };
  }
  if (input.lessonType === "video" && !input.videoId) {
    return { ok: false, error: "Pick a video for this lesson." };
  }

  const { data: last } = await db
    .from("lessons")
    .select("position")
    .eq("module_id", input.moduleId)
    .order("position", { ascending: false })
    .limit(1)
    .maybeSingle<{ position: number }>();

  const { error } = await db.from("lessons").insert({
    module_id: input.moduleId,
    title: input.title,
    lesson_type: input.lessonType,
    audio_id: input.lessonType === "audio" ? input.audioId : null,
    video_id: input.lessonType === "video" ? input.videoId : null,
    body_markdown: input.lessonType === "text" ? input.bodyMarkdown : null,
    position: (last?.position ?? -1) + 1,
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath(`/courses/${input.courseId}`);
  return { ok: true };
}

export async function deleteLesson(args: {
  lessonId: string;
  courseId: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db.from("lessons").delete().eq("id", args.lessonId);
  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function moveLesson(args: {
  lessonId: string;
  moduleId: string;
  courseId: string;
  direction: "up" | "down";
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { data: lessons } = await db
    .from("lessons")
    .select("id, position")
    .eq("module_id", args.moduleId)
    .order("position", { ascending: true })
    .order("created_at", { ascending: true })
    .returns<{ id: string; position: number }[]>();

  if (!lessons) return { ok: false, error: "Could not load lessons" };

  const index = lessons.findIndex((l) => l.id === args.lessonId);
  const swapWith = args.direction === "up" ? index - 1 : index + 1;
  if (index < 0 || swapWith < 0 || swapWith >= lessons.length) {
    return { ok: true };
  }

  const reordered = [...lessons];
  [reordered[index], reordered[swapWith]] = [reordered[swapWith], reordered[index]];

  for (let i = 0; i < reordered.length; i++) {
    const { error } = await db
      .from("lessons")
      .update({ position: i })
      .eq("id", reordered[i].id);
    if (error) return { ok: false, error: error.message };
  }

  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}
