create table public.videos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  description text,
  thumbnail_url text,
  trailer_url text,
  duration_seconds int,
  release_date date,
  language text,
  video_type text not null default 'movie'
    check (video_type in ('movie', 'episode')),
  season_number int,
  episode_number int,
  -- groups episodes under a "series" represented by a movie-type parent row
  parent_video_id uuid references public.videos (id) on delete cascade,
  is_premium boolean not null default true,
  status text not null default 'draft'
    check (status in ('draft', 'processing', 'published', 'archived')),
  r2_path text,
  drm_key_id text,
  view_count bigint not null default 0,
  avg_rating numeric(3, 2),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_episode_has_parent
    check (video_type = 'movie' or parent_video_id is not null)
);

create index idx_videos_status on public.videos (status);
create index idx_videos_parent_video_id on public.videos (parent_video_id);
create index idx_videos_release_date on public.videos (release_date desc);
create index idx_videos_title_trgm on public.videos using gin (title gin_trgm_ops);

create trigger trg_videos_updated_at
  before update on public.videos
  for each row execute function public.set_updated_at();

create table public.video_categories (
  video_id uuid not null references public.videos (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete cascade,
  primary key (video_id, category_id)
);

create index idx_video_categories_category_id on public.video_categories (category_id);

-- RLS
alter table public.videos enable row level security;
alter table public.video_categories enable row level security;

create policy "videos_select_published"
  on public.videos for select
  using (status = 'published' or public.is_admin());

create policy "videos_admin_manage"
  on public.videos for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "video_categories_select_all"
  on public.video_categories for select
  using (true);

create policy "video_categories_admin_manage"
  on public.video_categories for all
  using (public.is_admin())
  with check (public.is_admin());
