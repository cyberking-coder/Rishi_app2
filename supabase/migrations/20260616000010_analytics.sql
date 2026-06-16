create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  device_id uuid references public.devices (id) on delete set null,
  video_id uuid references public.videos (id) on delete cascade,
  audio_id uuid references public.audios (id) on delete cascade,
  session_id uuid,
  event_type text not null
    check (event_type in (
      'play', 'pause', 'seek', 'buffer', 'complete',
      'error', 'download_start', 'download_complete'
    )),
  event_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint chk_analytics_at_most_one_content
    check (num_nonnulls(video_id, audio_id) <= 1)
);

-- High write volume table: keep indexes minimal, partition-friendly by time
create index idx_analytics_events_occurred_at on public.analytics_events (occurred_at desc);
create index idx_analytics_events_video_id on public.analytics_events (video_id);
create index idx_analytics_events_audio_id on public.analytics_events (audio_id);
create index idx_analytics_events_user_id on public.analytics_events (user_id);
create index idx_analytics_events_type on public.analytics_events (event_type);

-- Daily rollup, refreshed by a scheduled job, used for admin dashboards
create table public.content_analytics_daily (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('video', 'audio')),
  content_id uuid not null,
  day date not null,
  total_views bigint not null default 0,
  total_watch_seconds bigint not null default 0,
  unique_viewers bigint not null default 0,
  created_at timestamptz not null default now()
);

create unique index uq_content_analytics_daily
  on public.content_analytics_daily (content_type, content_id, day);

create index idx_content_analytics_daily_day on public.content_analytics_daily (day desc);

-- RLS
alter table public.analytics_events enable row level security;
alter table public.content_analytics_daily enable row level security;

create policy "analytics_events_insert_own"
  on public.analytics_events for insert
  with check (user_id = auth.uid() or user_id is null);

create policy "analytics_events_admin_select"
  on public.analytics_events for select
  using (public.is_admin());

create policy "analytics_events_admin_manage"
  on public.analytics_events for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "content_analytics_daily_admin_select"
  on public.content_analytics_daily for select
  using (public.is_admin());

create policy "content_analytics_daily_admin_manage"
  on public.content_analytics_daily for all
  using (public.is_admin())
  with check (public.is_admin());
