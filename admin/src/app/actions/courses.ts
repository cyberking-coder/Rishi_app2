"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { slugify } from "@/lib/utils";
import type { CourseStatus, LessonType, ResourceType } from "@/lib/types";
import type { ActionResult } from "./users";
import { shrinkImage } from "@/lib/image";

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
  isPremium?: boolean;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const patch: Record<string, unknown> = {};
  if (args.title !== undefined) patch.title = args.title;
  if (args.description !== undefined) patch.description = args.description;
  if (args.categoryId !== undefined) patch.category_id = args.categoryId || null;
  if (args.isPremium !== undefined) patch.is_premium = args.isPremium;

  const { error } = await db.from("courses").update(patch).eq("id", args.courseId);
  if (error) return { ok: false, error: error.message };

  revalidatePath("/courses");
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

/** Uploads a course cover image to the public `covers` bucket (same
 *  bucket the audio/video cover art uses) and stores its URL. Passed as
 *  base64 since cover files are small. */
export async function uploadCourseCover(args: {
  courseId: string;
  fileName: string;
  contentType: string;
  base64: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const shrunk = await shrinkImage(
    Buffer.from(args.base64, "base64"),
    args.contentType,
    args.fileName.includes(".") ? args.fileName.split(".").pop()! : "jpg",
  );
  // The extension comes from what was actually stored, not from what
  // the admin picked: a PNG re-encoded to JPEG under a .png path is a
  // file whose name lies about its contents.
  const path = `course/${args.courseId}/cover.${shrunk.ext}`;

  const { error: uploadError } = await db.storage
    .from("covers")
    .upload(path, shrunk.bytes, {
      contentType: shrunk.contentType,
      upsert: true,
    });
  if (uploadError) return { ok: false, error: uploadError.message };

  const { data } = db.storage.from("covers").getPublicUrl(path);
  const { error: updateError } = await db
    .from("courses")
    .update({ cover_image_url: data.publicUrl })
    .eq("id", args.courseId);
  if (updateError) return { ok: false, error: updateError.message };

  revalidatePath("/courses");
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

/** Pricing and seat limit. Kept separate from updateCourse so the
 *  settings panel can save commercial terms without touching content
 *  fields, and so a bad price can never be a side effect of a title edit. */
export async function updateCoursePricing(args: {
  courseId: string;
  /** Rupees as typed by the admin; stored as paise. */
  priceRupees: number;
  seatLimit: number | null;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  if (!Number.isFinite(args.priceRupees) || args.priceRupees < 0) {
    return { ok: false, error: "Price must be zero or more." };
  }
  if (args.seatLimit !== null && (!Number.isInteger(args.seatLimit) || args.seatLimit < 1)) {
    return { ok: false, error: "Seat limit must be a whole number above zero." };
  }

  const priceAmount = Math.round(args.priceRupees * 100);

  // Selling below Razorpay's floor produces an order the gateway rejects
  // at checkout, which reads to the buyer as a broken site.
  if (priceAmount > 0 && priceAmount < 100) {
    return { ok: false, error: "Paid courses must be priced at ₹1 or more." };
  }

  const { error } = await db
    .from("courses")
    .update({
      price_amount: priceAmount,
      // A paid course is by definition not free content.
      is_premium: priceAmount > 0,
      seat_limit: args.seatLimit,
    })
    .eq("id", args.courseId);

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
): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
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

  const { data, error } = await db
    .from("lessons")
    .insert({
      module_id: input.moduleId,
      title: input.title,
      lesson_type: input.lessonType,
      audio_id: input.lessonType === "audio" ? input.audioId : null,
      video_id: input.lessonType === "video" ? input.videoId : null,
      body_markdown: input.lessonType === "text" ? input.bodyMarkdown : null,
      position: (last?.position ?? -1) + 1,
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    return { ok: false, error: error?.message ?? "Could not create lesson" };
  }
  revalidatePath(`/courses/${input.courseId}`);
  return { ok: true, id: data.id };
}

// ── Lesson resources ─────────────────────────────────────────────────
// Handouts and links attached to a lesson. Separate from the lesson's
// own media because a worksheet supports a lesson rather than being one.

export async function addLessonResource(args: {
  lessonId: string;
  courseId: string;
  title: string;
  resourceType: ResourceType;
  url: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  if (!args.title.trim()) return { ok: false, error: "Give the resource a name." };
  if (!args.url.trim()) return { ok: false, error: "The resource has no URL." };

  const { data: last } = await db
    .from("lesson_resources")
    .select("position")
    .eq("lesson_id", args.lessonId)
    .order("position", { ascending: false })
    .limit(1)
    .maybeSingle<{ position: number }>();

  const { error } = await db.from("lesson_resources").insert({
    lesson_id: args.lessonId,
    title: args.title.trim(),
    resource_type: args.resourceType,
    url: args.url.trim(),
    position: (last?.position ?? -1) + 1,
  });

  if (error) return { ok: false, error: error.message };
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function deleteLessonResource(args: {
  resourceId: string;
  courseId: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("lesson_resources")
    .delete()
    .eq("id", args.resourceId);

  if (error) return { ok: false, error: error.message };
  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

/** Uploads a lesson handout (PDF / image / any file) to the public
 *  `covers` bucket and returns its URL for attaching to a lesson.
 *
 *  These deliberately do NOT go through R2 + signed-URL licensing: that
 *  pipeline exists to protect streamed audio/video, and a course handout
 *  is already only reachable from inside a course the user paid for.
 *  Routing it through licensing would mean a new edge function for no
 *  additional protection. */
export async function uploadLessonResource(args: {
  courseId: string;
  fileName: string;
  contentType: string;
  base64: string;
}): Promise<{ ok: true; url: string } | { ok: false; error: string }> {
  await requireAdmin();
  const db = createAdminClient();

  const bytes = Buffer.from(args.base64, "base64");
  // 25 MB. Server Actions cap the request body, and a handout past this
  // size should be a link to a hosted file instead.
  if (bytes.byteLength > 25 * 1024 * 1024) {
    return { ok: false, error: "Files must be under 25 MB. Use a link instead." };
  }

  const safeName = args.fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
  const path = `lesson/${args.courseId}/${Date.now().toString(36)}-${safeName}`;

  const { error: uploadError } = await db.storage
    .from("covers")
    .upload(path, bytes, { contentType: args.contentType, upsert: false });
  if (uploadError) return { ok: false, error: uploadError.message };

  const { data } = db.storage.from("covers").getPublicUrl(path);
  return { ok: true, url: data.publicUrl };
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

// ── Enrolment access ─────────────────────────────────────────────────────

/**
 * Revokes or restores one student's access to one course.
 *
 * Moves the row between 'paid' and 'revoked' rather than dating
 * `expires_at`, because uq_course_purchases_paid allows only one paid
 * row per (user, course). Leaving a withdrawn enrolment as 'paid' meant
 * the student could never buy the course again — checkout refused them
 * as already owning it, and had it not, the webhook's update to 'paid'
 * would have hit the unique index after their card was charged.
 *
 * The revoked row keeps its amount and payment id, so the sale stays on
 * the books; has_course_access() requires 'paid', so access ends at
 * once. Ending a user's SUBSCRIPTION access does none of this — courses
 * are sold outright, so a lapsed subscription leaves a bought course
 * open on purpose, and this is the control for taking one back.
 */
export async function setCourseEnrolmentAccess(
  userId: string,
  courseId: string,
  revoked: boolean,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  if (!revoked) {
    // Restoring can collide: if the student rebought the course after
    // being removed, they already hold an active row and promoting the
    // old one would violate the unique index. Say so rather than
    // surfacing a constraint error.
    const { data: active } = await db
      .from("course_purchases")
      .select("id")
      .eq("user_id", userId)
      .eq("course_id", courseId)
      .eq("status", "paid")
      .maybeSingle();

    if (active) {
      return {
        ok: false,
        error: "This student already has an active enrolment — they " +
          "bought the course again after being removed.",
      };
    }
  }

  const { error } = await db
    .from("course_purchases")
    .update({
      status: revoked ? "revoked" : "paid",
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId)
    .eq("course_id", courseId)
    .eq("status", revoked ? "paid" : "revoked");

  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${courseId}`);
  revalidatePath("/courses");
  revalidatePath("/users");
  return { ok: true };
}

// ── Certificate template ─────────────────────────────────────────────────

/** Uploads the admin's own certificate artwork for this course. */
export async function uploadCertificateTemplate(args: {
  courseId: string;
  fileName: string;
  contentType: string;
  base64: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const ext = args.fileName.includes(".")
    ? args.fileName.split(".").pop()
    : "png";
  // Same bucket as covers — it's public artwork either way, and reusing
  // it avoids a second bucket to provision and keep permissions on.
  const path = `course/${args.courseId}/certificate.${ext}`;
  const bytes = Buffer.from(args.base64, "base64");

  const { error: uploadError } = await db.storage
    .from("covers")
    .upload(path, bytes, { contentType: args.contentType, upsert: true });
  if (uploadError) return { ok: false, error: uploadError.message };

  const { data } = db.storage.from("covers").getPublicUrl(path);
  // Cache-busted: upsert reuses the path, so a re-upload would otherwise
  // keep showing the old artwork until the CDN expired it.
  const url = `${data.publicUrl}?v=${Date.now()}`;

  const { error: updateError } = await db
    .from("courses")
    .update({ certificate_template_url: url })
    .eq("id", args.courseId);
  if (updateError) return { ok: false, error: updateError.message };

  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

/** Where the recipient's name is printed, as percentages of the image. */
export async function updateCertificateLayout(args: {
  courseId: string;
  top: number;
  left: number;
  size: number;
  color: string;
}): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const { error } = await db
    .from("courses")
    .update({
      certificate_name_top: args.top,
      certificate_name_left: args.left,
      certificate_name_size: args.size,
      certificate_name_color: args.color,
    })
    .eq("id", args.courseId);

  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${args.courseId}`);
  return { ok: true };
}

export async function removeCertificateTemplate(
  courseId: string,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  // Only the reference is cleared; the file stays in the bucket. The
  // course falls back to the app's own drawn certificate, and any
  // certificate already issued keeps rendering from whatever the app
  // does now — the artwork was never baked into the record.
  const { error } = await db
    .from("courses")
    .update({ certificate_template_url: null })
    .eq("id", courseId);

  if (error) return { ok: false, error: error.message };

  revalidatePath(`/courses/${courseId}`);
  return { ok: true };
}

/**
 * Enrols somebody in a course without a payment.
 *
 * The roster could only ever revoke and restore, which needs a purchase
 * row to already exist — so there was no way to let anybody into a
 * course who had not bought it. That covers the cases a payment cannot:
 * a review or demo account, an offline cohort, a refunded student being
 * made whole, a comp. The Award button on this same roster exists for
 * exactly the same reason on the certificate side.
 *
 * Written as a purchase at `amount: 0` rather than as a separate kind of
 * grant. has_course_access() only looks for a paid, unexpired row, so
 * anything else would need a second branch in the one function that
 * decides who can watch what — and revenue totals stay honest because
 * the row records what was actually charged, which was nothing.
 *
 * A revoked row is promoted rather than joined by a second one: the
 * unique index only covers 'paid', so an insert would succeed and leave
 * two rows for one student, which is how the roster's dedupe starts
 * disagreeing with itself.
 */
export async function grantCourseAccess(
  email: string,
  courseId: string,
): Promise<ActionResult> {
  await requireAdmin();
  const db = createAdminClient();

  const address = email.trim().toLowerCase();
  if (!address) return { ok: false, error: "Enter an email address." };

  // listUsers rather than a filtered query: auth.users is not reachable
  // through PostgREST, and there is no admin lookup-by-email endpoint.
  const { data: list, error: listError } = await db.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  if (listError) return { ok: false, error: listError.message };

  const user = (list?.users ?? []).find(
    (u) => u.email?.toLowerCase() === address,
  );
  if (!user) {
    return {
      ok: false,
      error:
        `No account exists for ${address}. They need to sign up first — ` +
        `access is granted to an account, not to an address.`,
    };
  }

  const { data: existing } = await db
    .from("course_purchases")
    .select("id, status")
    .eq("user_id", user.id)
    .eq("course_id", courseId)
    .in("status", ["paid", "revoked"])
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle<{ id: string; status: string }>();

  if (existing?.status === "paid") {
    return { ok: false, error: "That account already has access to this course." };
  }

  if (existing) {
    const { error } = await db
      .from("course_purchases")
      .update({ status: "paid", updated_at: new Date().toISOString() })
      .eq("id", existing.id);
    if (error) return { ok: false, error: error.message };
  } else {
    const { error } = await db.from("course_purchases").insert({
      user_id: user.id,
      course_id: courseId,
      amount: 0,
      currency: "INR",
      status: "paid",
    });
    if (error) return { ok: false, error: error.message };
  }

  revalidatePath(`/courses/${courseId}`);
  return { ok: true };
}
