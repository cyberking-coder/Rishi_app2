-- Per-course pricing + richer lesson content types.
--
-- Two changes that arrive together because the admin course builder needs
-- both at once:
--
-- 1. Courses become individually purchasable products. Until now every
--    course was gated by the blanket "Rishi Mode" subscription via
--    has_active_access(). From here a course carries its own price, and
--    access to it comes from a row in course_purchases — the subscription
--    no longer governs course access. Audio/video content OUTSIDE courses
--    is untouched and still uses the subscription.
--
-- 2. Lessons can hold PDFs, images, downloadable files and embedded links
--    in addition to audio/video/text.
--
-- Note on `courses.is_premium`: kept, but it now only means "not free".
-- The real gate is price_amount > 0 plus a purchase row. It stays because
-- the mobile catalog and the admin list both read it, and dropping it
-- would be a wider change than this migration needs.

-- ---------------------------------------------------------------------------
-- 1. Course pricing
-- ---------------------------------------------------------------------------

alter table public.courses
  -- Minor units (paise), matching how Razorpay and subscription_plans
  -- already store money — storing rupees as a decimal here would make this
  -- the only place in the schema that needs rounding rules.
  add column if not exists price_amount int not null default 0,
  add column if not exists currency text not null default 'INR',
  -- null = unlimited seats. A number caps total purchases, which is what
  -- drives the "only N seats left" copy.
  add column if not exists seat_limit int,
  add column if not exists short_description text;

alter table public.courses
  add constraint chk_courses_price_non_negative
    check (price_amount >= 0);

alter table public.courses
  add constraint chk_courses_seat_limit_positive
    check (seat_limit is null or seat_limit > 0);

-- ---------------------------------------------------------------------------
-- 2. course_purchases — one row per (user, course) that has been paid for
-- ---------------------------------------------------------------------------
create table if not exists public.course_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  -- Money is recorded as charged, not looked up from the course later —
  -- the price can change after the sale and the receipt must not.
  amount int not null,
  currency text not null default 'INR',
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'failed', 'refunded')),
  razorpay_order_id text,
  razorpay_payment_id text,
  -- Optional expiry for time-limited course access. null = forever.
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One paid row per user per course. Partial so a failed attempt doesn't
-- block a later successful one.
create unique index if not exists uq_course_purchases_paid
  on public.course_purchases (user_id, course_id)
  where status = 'paid';

create index if not exists idx_course_purchases_user
  on public.course_purchases (user_id, status);
create index if not exists idx_course_purchases_course
  on public.course_purchases (course_id, status);
-- Unique, not just indexed: the webhook upserts on this so a retried
-- delivery updates the pending row from checkout instead of inserting a
-- second purchase for the same payment.
create unique index if not exists uq_course_purchases_order
  on public.course_purchases (razorpay_order_id)
  where razorpay_order_id is not null;

create trigger trg_course_purchases_updated_at
  before update on public.course_purchases
  for each row execute function public.set_updated_at();

alter table public.course_purchases enable row level security;

-- Users read their own purchases; admins read everything. Writes are
-- service-role only — the webhook is the single place a purchase becomes
-- 'paid', exactly as with subscription grants.
create policy "course_purchases_select_own_or_admin"
  on public.course_purchases for select
  using (user_id = auth.uid() or public.is_admin());

create policy "course_purchases_admin_manage"
  on public.course_purchases for all
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- 3. has_course_access() — the single source of truth for course gating
-- ---------------------------------------------------------------------------
-- Mirrors has_active_access()'s shape so callers (RLS, edge functions, the
-- app) reason about course access the same way they already reason about
-- subscription access.
create or replace function public.has_course_access(
  p_user_id uuid,
  p_course_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    -- A free course is open to any signed-in user.
    exists (
      select 1 from public.courses c
      where c.id = p_course_id and c.price_amount = 0
    )
    -- Admins see everything, so content can be checked before launch.
    or exists (
      select 1 from public.profiles p
      where p.id = p_user_id and p.role = 'admin'
    )
    -- A completed purchase that hasn't lapsed.
    or exists (
      select 1 from public.course_purchases cp
      where cp.user_id = p_user_id
        and cp.course_id = p_course_id
        and cp.status = 'paid'
        and (cp.expires_at is null or cp.expires_at > now())
    );
$$;

grant execute on function public.has_course_access(uuid, uuid) to authenticated;

-- Seats sold, for the "only N left" counter. Kept as a function rather
-- than a denormalised column so it can never drift from the purchase rows.
create or replace function public.course_seats_taken(p_course_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.course_purchases
  where course_id = p_course_id and status = 'paid';
$$;

grant execute on function public.course_seats_taken(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 4. Richer lesson content types
-- ---------------------------------------------------------------------------
-- Files (pdf/image/file) live in the public `covers` bucket alongside
-- cover art rather than the private R2 bucket. These are course handouts,
-- not the premium media the licensing pipeline protects, and routing them
-- through signed-URL issuance would mean a new edge function for content
-- that is already only reachable behind a purchased course.
alter table public.lessons
  add column if not exists resource_url text,
  add column if not exists resource_name text;

alter table public.lessons
  drop constraint if exists lessons_lesson_type_check;

alter table public.lessons
  add constraint lessons_lesson_type_check check (
    lesson_type in ('audio', 'video', 'text', 'pdf', 'image', 'file', 'link')
  );

-- Replace the payload check so the new types must carry a resource_url,
-- the same way a text lesson must carry a body.
alter table public.lessons
  drop constraint if exists chk_lesson_payload;

alter table public.lessons
  add constraint chk_lesson_payload check (
    (lesson_type = 'text' and body_markdown is not null)
    or (lesson_type in ('pdf', 'image', 'file', 'link') and resource_url is not null)
    or lesson_type in ('audio', 'video')
  );

-- ---------------------------------------------------------------------------
-- 5. Media reachable through a purchased course
-- ---------------------------------------------------------------------------
-- A lesson points at an existing audios/videos row, and that row carries
-- its own is_premium flag which the license functions check against the
-- subscription. Without this, buying a course would not actually let you
-- play its premium lessons — the license function would still ask "does
-- this user have an active subscription?" and refuse.
--
-- Note this grants access to the media ROW, which may also appear in the
-- standalone catalog. That is intended: buying a course buys its content,
-- wherever else that content happens to be listed.
create or replace function public.has_media_access_via_course(
  p_user_id uuid,
  p_content_type text,
  p_content_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.lessons l
    join public.course_modules m on m.id = l.module_id
    where (
        (p_content_type = 'audio' and l.audio_id = p_content_id)
        or (p_content_type = 'video' and l.video_id = p_content_id)
      )
      and public.has_course_access(p_user_id, m.course_id)
  );
$$;

grant execute on function public.has_media_access_via_course(uuid, text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Course RLS: published courses stay publicly listable
-- ---------------------------------------------------------------------------
-- Deliberately unchanged. The catalog must remain visible to someone who
-- has NOT bought the course — that listing is what sells it. Purchase is
-- enforced at playback (issue-*-license) and by the app's lock UI, not by
-- hiding the course from the catalog.
