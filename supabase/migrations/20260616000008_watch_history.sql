create table public.watch_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  video_id uuid references public.videos (id) on delete cascade,
  audio_id uuid references public.audios (id) on delete cascade,
  device_id uuid references public.devices (id) on delete set null,
  progress_seconds int not null default 0,
  duration_seconds int,
  completed boolean not null default false,
  last_watched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint chk_exactly_one_content
    check (num_nonnulls(video_id, audio_id) = 1)
);

create unique index uq_watch_history_user_video
  on public.watch_history (user_id, video_id)
  where (video_id is not null);

create unique index uq_watch_history_user_audio
  on public.watch_history (user_id, audio_id)
  where (audio_id is not null);

create index idx_watch_history_user_recent
  on public.watch_history (user_id, last_watched_at desc);

-- RLS
alter table public.watch_history enable row level security;

create policy "watch_history_select_own_or_admin"
  on public.watch_history for select
  using (user_id = auth.uid() or public.is_admin());

create policy "watch_history_upsert_own"
  on public.watch_history for insert
  with check (user_id = auth.uid());

create policy "watch_history_update_own"
  on public.watch_history for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "watch_history_delete_own_or_admin"
  on public.watch_history for delete
  using (user_id = auth.uid() or public.is_admin());
