create table public.playlists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles (id) on delete cascade,
  title text not null,
  description text,
  cover_art_url text,
  -- system playlists are admin-curated and visible to everyone (e.g. "Top Picks")
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_owner_required_unless_system
    check (is_system or owner_id is not null)
);

create index idx_playlists_owner_id on public.playlists (owner_id);

create trigger trg_playlists_updated_at
  before update on public.playlists
  for each row execute function public.set_updated_at();

create table public.playlist_tracks (
  playlist_id uuid not null references public.playlists (id) on delete cascade,
  audio_id uuid not null references public.audios (id) on delete cascade,
  position int not null,
  added_at timestamptz not null default now(),
  primary key (playlist_id, audio_id)
);

create unique index uq_playlist_tracks_position
  on public.playlist_tracks (playlist_id, position);

-- RLS
alter table public.playlists enable row level security;
alter table public.playlist_tracks enable row level security;

create policy "playlists_select_own_or_system_or_admin"
  on public.playlists for select
  using (is_system or owner_id = auth.uid() or public.is_admin());

create policy "playlists_manage_own"
  on public.playlists for all
  using (owner_id = auth.uid() and not is_system)
  with check (owner_id = auth.uid() and not is_system);

create policy "playlists_admin_manage_system"
  on public.playlists for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "playlist_tracks_select_via_playlist"
  on public.playlist_tracks for select
  using (
    exists (
      select 1 from public.playlists p
      where p.id = playlist_tracks.playlist_id
        and (p.is_system or p.owner_id = auth.uid() or public.is_admin())
    )
  );

create policy "playlist_tracks_manage_via_own_playlist"
  on public.playlist_tracks for all
  using (
    exists (
      select 1 from public.playlists p
      where p.id = playlist_tracks.playlist_id and p.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.playlists p
      where p.id = playlist_tracks.playlist_id and p.owner_id = auth.uid()
    )
  );

create policy "playlist_tracks_admin_manage"
  on public.playlist_tracks for all
  using (public.is_admin())
  with check (public.is_admin());
