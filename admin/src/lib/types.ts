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
export type LessonType =
  | "audio"
  | "video"
  | "text"
  | "pdf"
  | "image"
  | "file"
  | "link";

/** Lesson types whose payload is a URL in `resource_url` rather than
 *  attached media or inline markdown. */
export const RESOURCE_LESSON_TYPES = ["pdf", "image", "file", "link"] as const;

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
