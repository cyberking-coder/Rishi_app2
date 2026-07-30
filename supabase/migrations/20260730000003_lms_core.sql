-- Phase 4: LMS core — courses -> modules -> lessons, plus per-lesson progress.
--
-- Additive only. Nothing existing is altered, so current audio playback,
-- downloads, admin workflows and payments are untouched.
--
-- Deliberate deviations from the roadmap's table sketch, each for a reason:
--
--  * No unique index on `position`. playlist_tracks has one
--    (uq_playlist_tracks_position), but it makes reordering violate the
--    constraint mid-swap and there is no existing reorder RPC in this
--    codebase to copy. Plain `position` ordered with created_at as a
--    tie-break keeps reordering a simple UPDATE.
--
--  * `courses.category_id` is a single nullable FK rather than a
--    `course_categories` join table. The roadmap describes a course as
--    "optionally belonging to a category" (singular); the many-to-many
--    join used by audios/videos would be more machinery than that needs.
--
--  * No `course_enrollments` table. "My courses" is derived from
--    lesson_progress via a join, which is cheap at this scale. A
--    denormalized table would be a second write path that can drift out
--    of sync with the progress rows it summarizes.
--
-- Access gating note: a lesson references an existing audios/videos row,
-- and playback is authorized server-side by that row's own is_premium
-- (via issue-audio-license / issue-playback-license, unchanged). So
-- courses.is_premium governs catalog visibility and the app's lock UI,
-- while the underlying content row governs playback. The admin course
-- builder keeps these aligned: fresh uploads inherit the course's flag,
-- and reusing existing content warns when the two disagree.

-- ---------------------------------------------------------------------------
-- courses
-- ---------------------------------------------------------------------------
create table public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  description text,
  cover_image_url text,
  category_id uuid references public.categories (id) on delete set null,
  is_premium boolean not null default true,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'archived')),
  sort_order int not null default 0,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_courses_status on public.courses (status);
create index idx_courses_category on public.courses (category_id);

create trigger trg_courses_updated_at
  before update on public.courses
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- course_modules — ordered groups of lessons within one course
-- ---------------------------------------------------------------------------
create table public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  title text not null,
  description text,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_course_modules_course on public.course_modules (course_id, position);

create trigger trg_course_modules_updated_at
  before update on public.course_modules
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- lessons
-- ---------------------------------------------------------------------------
-- A lesson never owns its own media. Audio/video lessons point at an
-- existing audios/videos row, so the whole proven R2 + licensing pipeline
-- is reused as-is; the course builder's "upload new" path just creates
-- that row first via the normal content-upload flow. Text lessons carry
-- their body inline.
--
-- 'video' is permitted in lesson_type from day one even though the app has
-- no video player yet, so adding one later needs no migration.
create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.course_modules (id) on delete cascade,
  title text not null,
  description text,
  lesson_type text not null check (lesson_type in ('audio', 'video', 'text')),
  audio_id uuid references public.audios (id) on delete set null,
  video_id uuid references public.videos (id) on delete set null,
  body_markdown text,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Each lesson type must carry the payload it claims to have. Media rows
  -- are ON DELETE SET NULL rather than CASCADE so deleting an audio never
  -- silently removes lessons from a course - but that means a lesson can
  -- legitimately exist with a dangling reference, which the app renders as
  -- "content unavailable" rather than treating as corrupt data.
  constraint chk_lesson_payload check (
    (lesson_type = 'text' and body_markdown is not null)
    or lesson_type in ('audio', 'video')
  )
);

create index idx_lessons_module on public.lessons (module_id, position);
create index idx_lessons_audio on public.lessons (audio_id) where audio_id is not null;
create index idx_lessons_video on public.lessons (video_id) where video_id is not null;

create trigger trg_lessons_updated_at
  before update on public.lessons
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- lesson_progress
-- ---------------------------------------------------------------------------
-- Mirrors watch_history's intent, but with a single content FK instead of
-- watch_history's polymorphic video_id/audio_id pair. That means a plain
-- unique constraint works, so clients can use a normal PostgREST upsert -
-- watch_history needs the upsert_watch_progress RPC precisely because its
-- partial indexes can't be targeted by ON CONFLICT.
create table public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  progress_seconds int not null default 0,
  completed boolean not null default false,
  last_accessed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint uq_lesson_progress_user_lesson unique (user_id, lesson_id)
);

create index idx_lesson_progress_user on public.lesson_progress (user_id, last_accessed_at desc);
create index idx_lesson_progress_lesson on public.lesson_progress (lesson_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.courses enable row level security;
alter table public.course_modules enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_progress enable row level security;

-- Courses: same published-or-admin rule as audios/videos.
create policy "courses_select_published"
  on public.courses for select
  using (status = 'published' or public.is_admin());

create policy "courses_admin_manage"
  on public.courses for all
  using (public.is_admin())
  with check (public.is_admin());

-- Modules/lessons: visibility follows the parent course, matching the
-- playlist_tracks "check the parent" pattern.
create policy "course_modules_select_via_course"
  on public.course_modules for select
  using (
    exists (
      select 1 from public.courses c
      where c.id = course_modules.course_id
        and (c.status = 'published' or public.is_admin())
    )
  );

create policy "course_modules_admin_manage"
  on public.course_modules for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "lessons_select_via_course"
  on public.lessons for select
  using (
    exists (
      select 1
      from public.course_modules m
      join public.courses c on c.id = m.course_id
      where m.id = lessons.module_id
        and (c.status = 'published' or public.is_admin())
    )
  );

create policy "lessons_admin_manage"
  on public.lessons for all
  using (public.is_admin())
  with check (public.is_admin());

-- Progress: own-or-admin, split by verb (the watch_history pattern).
create policy "lesson_progress_select_own_or_admin"
  on public.lesson_progress for select
  using (user_id = auth.uid() or public.is_admin());

create policy "lesson_progress_insert_own"
  on public.lesson_progress for insert
  with check (user_id = auth.uid());

create policy "lesson_progress_update_own"
  on public.lesson_progress for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "lesson_progress_delete_own_or_admin"
  on public.lesson_progress for delete
  using (user_id = auth.uid() or public.is_admin());
