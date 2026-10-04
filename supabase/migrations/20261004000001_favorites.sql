-- User favourites — AUDIO only (per product: the Favourites section carries
-- audios exclusively). One row per (user, audio). A heart toggle inserts/
-- deletes a row; the Favourites screen lists the user's own rows.

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  audio_id uuid not null references public.audios (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint uq_favorites_user_audio unique (user_id, audio_id)
);

create index if not exists idx_favorites_user
  on public.favorites (user_id, created_at desc);

alter table public.favorites enable row level security;

-- A user sees and manages only their own favourites.
create policy "favorites_select_own"
  on public.favorites for select
  using (user_id = auth.uid());

create policy "favorites_insert_own"
  on public.favorites for insert
  with check (user_id = auth.uid());

create policy "favorites_delete_own"
  on public.favorites for delete
  using (user_id = auth.uid());
