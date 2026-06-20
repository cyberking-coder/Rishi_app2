-- Retreat access window + "next event" pop-up.
--
-- The app is handed out at an Anurag _Rishi retreat. Each attendee's account
-- gets a 30-day access window; once it lapses they see no audio and their
-- offline downloads are purged. A separate, admin-editable pop-up advertises
-- the next event and starts showing on a date you choose.

-- ---------------------------------------------------------------------------
-- Per-user access window
-- ---------------------------------------------------------------------------
-- access_started_at: when the attendee's window opened (account creation).
-- access_expires_at: hard deadline. Null == no expiry (e.g. staff/admin).
alter table public.profiles
  add column if not exists access_started_at timestamptz,
  add column if not exists access_expires_at timestamptz;

create index if not exists idx_profiles_access_expires
  on public.profiles (access_expires_at);

-- Authoritative server-side check: is the calling user's access still valid?
-- Used by the playback edge function so a device clock change can't bypass it.
create or replace function public.has_active_access(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select access_expires_at is null or access_expires_at > now()
       from public.profiles where id = p_user_id),
    false
  );
$$;

-- ---------------------------------------------------------------------------
-- app_config — a single global row of app-wide settings (the pop-up).
-- ---------------------------------------------------------------------------
create table if not exists public.app_config (
  -- Enforce a single row: id is always true.
  id boolean primary key default true check (id),
  popup_enabled boolean not null default false,
  -- The pop-up only shows on/after this moment (e.g. day 6 of the retreat).
  popup_start_at timestamptz,
  popup_title text,
  popup_body text,
  popup_image_url text,
  updated_at timestamptz not null default now()
);

create trigger trg_app_config_updated_at
  before update on public.app_config
  for each row execute function public.set_updated_at();

-- Seed the singleton so the app always has a row to read.
insert into public.app_config (id, popup_enabled)
values (true, false)
on conflict (id) do nothing;

alter table public.app_config enable row level security;

-- Any signed-in user can read the pop-up config; only admins may change it.
create policy "app_config_select_authenticated"
  on public.app_config for select
  using (auth.uid() is not null);

create policy "app_config_admin_manage"
  on public.app_config for all
  using (public.is_admin())
  with check (public.is_admin());
