// Hand-maintained shapes for the tables the admin dashboard reads/writes.
// (For a fully typed client, generate with `supabase gen types typescript`.)

export type ContentStatus = "draft" | "processing" | "published" | "archived";
export type UserRole = "user" | "admin" | "content_manager" | "support";
export type UserStatus = "active" | "suspended" | "banned";

export interface Profile {
  id: string;
  display_name: string | null;
  avatar_url: string | null;
  role: UserRole;
  subscription_tier: string;
  country: string | null;
  status: UserStatus;
  access_started_at: string | null;
  access_expires_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface DeviceRow {
  id: string;
  user_id: string;
  device_fingerprint: string;
  device_name: string | null;
  platform: "android" | "ios" | "web";
  is_active: boolean;
  last_seen_at: string;
  bound_at: string;
  created_at: string;
}

export interface Video {
  id: string;
  title: string;
  slug: string;
  description: string | null;
  thumbnail_url: string | null;
  duration_seconds: number | null;
  language: string | null;
  video_type: "movie" | "episode";
  is_premium: boolean;
  status: ContentStatus;
  r2_path: string | null;
  bunny_video_id: string | null;
  bunny_status: "uploading" | "processing" | "ready" | "failed" | null;
  view_count: number;
  created_at: string;
  updated_at: string;
}

export interface Audio {
  id: string;
  title: string;
  slug: string;
  description: string | null;
  cover_art_url: string | null;
  duration_seconds: number | null;
  artist: string | null;
  album: string | null;
  audio_type: "track" | "podcast_episode";
  is_premium: boolean;
  status: ContentStatus;
  r2_path: string | null;
  play_count: number;
  created_at: string;
  updated_at: string;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  parent_id: string | null;
  content_type: "video" | "audio" | "both";
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export type ContentKind = "video" | "audio";

// ── LMS ──────────────────────────────────────────────────────────────────
// Courses have their own status set (no 'processing' — a course has no
// media of its own to transcode; its lessons reference content rows that
// carry that state themselves).
export type CourseStatus = "draft" | "published" | "archived";
export type LessonType = "audio" | "video" | "text";

/** Attachments that hang off a lesson: handouts and links, not teaching
 *  formats of their own. */
export type ResourceType = "pdf" | "image" | "file" | "link";

export interface LessonResource {
  id: string;
  lesson_id: string;
  title: string;
  resource_type: ResourceType;
  url: string;
  position: number;
  created_at: string;
  updated_at: string;
}

export interface Course {
  id: string;
  title: string;
  slug: string;
  description: string | null;
  cover_image_url: string | null;
  category_id: string | null;
  is_premium: boolean;
  status: CourseStatus;
  /** Minor units (paise). 0 means the course is free. */
  price_amount: number;
  currency: string;
  /** null means unlimited. */
  seat_limit: number | null;
  short_description: string | null;
  sort_order: number;
  /** Admin-uploaded certificate artwork. Null = the app draws its own. */
  certificate_template_url: string | null;
  /** Where the recipient's name is printed, as percentages of the image,
   *  so one template lands correctly at any resolution. */
  certificate_name_top: number;
  certificate_name_left: number;
  /** Font size as a percentage of image width. */
  certificate_name_size: number;
  certificate_name_color: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface CourseModule {
  id: string;
  course_id: string;
  title: string;
  description: string | null;
  position: number;
  created_at: string;
  updated_at: string;
}

export interface Lesson {
  id: string;
  module_id: string;
  title: string;
  description: string | null;
  lesson_type: LessonType;
  audio_id: string | null;
  video_id: string | null;
  body_markdown: string | null;
  /** Superseded by lesson_resources. Kept only because the column still
   *  exists; nothing reads these. */
  resource_url: string | null;
  resource_name: string | null;
  position: number;
  created_at: string;
  updated_at: string;
}

/** A lesson plus the media row it points at, for the builder's UI — lets
 *  it surface the attached title and warn when the media's is_premium
 *  disagrees with its course's. */
export interface LessonWithMedia extends Lesson {
  lesson_resources?: LessonResource[];
  audios: { id: string; title: string; is_premium: boolean } | null;
  videos: { id: string; title: string; is_premium: boolean } | null;
}

export interface CoursePurchase {
  id: string;
  user_id: string;
  course_id: string;
  amount: number;
  currency: string;
  status: "pending" | "paid" | "failed" | "refunded";
  razorpay_order_id: string | null;
  razorpay_payment_id: string | null;
  expires_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface Coupon {
  id: string;
  code: string;
  description: string | null;
  discount_type: "percent" | "flat";
  /** Percent: 1-100. Flat: minor units (paise). */
  discount_value: number;
  course_id: string | null;
  max_redemptions: number | null;
  times_redeemed: number;
  starts_at: string | null;
  expires_at: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface YoutubeVideo {
  id: string;
  title: string;
  description: string | null;
  youtube_url: string;
  youtube_id: string;
  thumbnail_url: string | null;
  category_id: string | null;
  is_published: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

// ── Live sessions ────────────────────────────────────────────────────────

export interface LiveSession {
  id: string;
  title: string;
  description: string | null;
  join_url: string;
  thumbnail_url: string | null;
  starts_at: string;
  duration_minutes: number;
  status: "scheduled" | "cancelled";
  /** Paise. Null or 0 = free to join. A priced session's join_url is
   *  blanked on the row and kept out of members' reach. */
  price_amount: number | null;
  currency: string;
  seat_limit: number | null;
  created_at: string;
  updated_at: string;
}

export interface SessionReminder {
  id: string;
  session_id: string;
  /** 60, 30 or 5. */
  minutes_before: number;
  sent_at: string;
  recipient_count: number;
}

// ── Certificates ─────────────────────────────────────────────────────────

export interface Certificate {
  id: string;
  user_id: string;
  course_id: string;
  certificate_number: string;
  /** Snapshotted at issue time — renaming the course must not rewrite
   *  certificates already awarded. */
  course_title: string;
  recipient_name: string | null;
  issued_at: string;
  revoked_at: string | null;
}
