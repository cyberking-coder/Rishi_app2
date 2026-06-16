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
