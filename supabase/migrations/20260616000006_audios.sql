create table public.audios (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text not null unique,
  description text,
  cover_art_url text,
  duration_seconds int,
  release_date date,
  language text,
  artist text,
  album text,
  audio_type text not null default 'track'
    check (audio_type in ('track', 'podcast_episode')),
  parent_audio_id uuid references public.audios (id) on delete cascade,
  is_premium boolean not null default true,
  status text not null default 'draft'
    check (status in ('draft', 'processing', 'published', 'archived')),
  r2_path text,
  drm_key_id text,
  play_count bigint not null default 0,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_audios_status on public.audios (status);
create index idx_audios_parent_audio_id on public.audios (parent_audio_id);
create index idx_audios_title_trgm on public.audios using gin (title gin_trgm_ops);

create trigger trg_audios_updated_at
  before update on public.audios
  for each row execute function public.set_updated_at();

create table public.audio_categories (
  audio_id uuid not null references public.audios (id) on delete cascade,
  category_id uuid not null references public.categories (id) on delete cascade,
  primary key (audio_id, category_id)
);

create index idx_audio_categories_category_id on public.audio_categories (category_id);

-- RLS
alter table public.audios enable row level security;
alter table public.audio_categories enable row level security;

create policy "audios_select_published"
  on public.audios for select
  using (status = 'published' or public.is_admin());

create policy "audios_admin_manage"
  on public.audios for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "audio_categories_select_all"
  on public.audio_categories for select
  using (true);

create policy "audio_categories_admin_manage"
  on public.audio_categories for all
  using (public.is_admin())
  with check (public.is_admin());
