-- Coupon codes for course checkout, and a curated list of free YouTube
-- videos surfaced in the app.

-- ---------------------------------------------------------------------------
-- 1. coupons
-- ---------------------------------------------------------------------------
-- A coupon is either a percentage off or a flat amount off. Both are
-- stored rather than normalising to one, because "20% off" and "₹200 off"
-- are different promises to the customer and collapsing them at write
-- time would lose the intent the admin typed.
create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  -- Stored uppercase; lookups upper() the input so codes are effectively
  -- case-insensitive without a functional index on every query.
  code text not null unique,
  description text,
  discount_type text not null check (discount_type in ('percent', 'flat')),
  -- percent: 1-100. flat: minor units (paise), same as course prices.
  discount_value int not null check (discount_value > 0),
  -- null = valid for every course. Set to restrict it to one course.
  course_id uuid references public.courses (id) on delete cascade,
  -- null = unlimited redemptions.
  max_redemptions int check (max_redemptions is null or max_redemptions > 0),
  times_redeemed int not null default 0,
  starts_at timestamptz,
  expires_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_percent_range check (
    discount_type <> 'percent' or discount_value between 1 and 100
  )
);

create index if not exists idx_coupons_active on public.coupons (is_active);
create index if not exists idx_coupons_course on public.coupons (course_id);

create trigger trg_coupons_updated_at
  before update on public.coupons
  for each row execute function public.set_updated_at();

alter table public.coupons enable row level security;

-- Only admins touch coupons directly. Redemption happens server-side in
-- the checkout route under the service role, so no public read policy is
-- needed — a public read would also hand out every unused code.
create policy "coupons_admin_manage"
  on public.coupons for all
  using (public.is_admin())
  with check (public.is_admin());

-- Record which coupon paid for which purchase, so redemptions can be
-- audited and a refund can be traced back to the discount that applied.
alter table public.course_purchases
  add column if not exists coupon_id uuid references public.coupons (id) on delete set null,
  add column if not exists discount_amount int not null default 0;

-- ---------------------------------------------------------------------------
-- 2. Atomic redemption
-- ---------------------------------------------------------------------------
-- Increments the counter only while the coupon is still valid, and
-- reports whether it won. Doing this as a single conditional UPDATE
-- rather than check-then-increment is what stops two simultaneous
-- checkouts from both taking the last redemption of a limited code.
create or replace function public.redeem_coupon(p_coupon_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated int;
begin
  update public.coupons
     set times_redeemed = times_redeemed + 1
   where id = p_coupon_id
     and is_active
     and (starts_at is null or starts_at <= now())
     and (expires_at is null or expires_at > now())
     and (max_redemptions is null or times_redeemed < max_redemptions);

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. youtube_videos — curated free content
-- ---------------------------------------------------------------------------
-- These are not app-hosted media: nothing streams through R2 or Bunny,
-- and no licensing applies. The app shows a thumbnail and hands off to
-- YouTube, which is why this table is deliberately separate from
-- `videos` rather than another status on it.
create table if not exists public.youtube_videos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  youtube_url text not null,
  -- Derived from the URL on write so the app never has to parse it.
  -- Also what builds the default thumbnail.
  youtube_id text not null,
  thumbnail_url text,
  category_id uuid references public.categories (id) on delete set null,
  is_published boolean not null default true,
  sort_order int not null default 0,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_youtube_published
  on public.youtube_videos (is_published, sort_order);

create trigger trg_youtube_videos_updated_at
  before update on public.youtube_videos
  for each row execute function public.set_updated_at();

alter table public.youtube_videos enable row level security;

-- Free content, so every signed-in user can list it. No premium gate:
-- the videos are public on YouTube anyway, and pretending otherwise
-- would be a lock with no door.
create policy "youtube_videos_select_published"
  on public.youtube_videos for select
  using (is_published or public.is_admin());

create policy "youtube_videos_admin_manage"
  on public.youtube_videos for all
  using (public.is_admin())
  with check (public.is_admin());
