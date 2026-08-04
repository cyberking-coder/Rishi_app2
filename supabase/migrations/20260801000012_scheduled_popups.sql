-- Scheduled pop-ups: more than one, each pinned to a day of the week.
--
-- The pop-up used to be three columns on the single app_config row, which
-- allowed exactly one message at a time. Wanting a Monday message and a
-- Wednesday message is not a variation on that — it is a list, and a list
-- belongs in rows.
--
-- app_config's popup_* columns are deliberately left in place rather than
-- dropped. Installed builds of the app still read them, and dropping the
-- columns would take the pop-up away from everyone who has not updated
-- yet. They are frozen, not live: the admin writes here from now on.

create table if not exists public.app_popups (
  id uuid primary key default gen_random_uuid(),
  title text,
  body text,
  image_url text,

  -- ISO-8601 weekday: 1 = Monday … 7 = Sunday. Null means every day,
  -- which is what the old single pop-up effectively was.
  weekday smallint check (weekday between 1 and 7),

  -- Nothing shows before this moment, whatever the weekday. Lets a
  -- Monday message be written now and start appearing three Mondays out.
  starts_at timestamptz,

  enabled boolean not null default true,

  -- Decides which one wins when two match the same day. Not a nicety:
  -- without a deterministic order, two pop-ups both set to Monday would
  -- alternate at random between app launches.
  sort_order int not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_app_popups_enabled
  on public.app_popups (enabled, sort_order);

drop trigger if exists trg_app_popups_updated_at on public.app_popups;
create trigger trg_app_popups_updated_at
  before update on public.app_popups
  for each row execute function public.set_updated_at();

alter table public.app_popups enable row level security;

-- Same shape as app_config: any signed-in user reads, only admins write.
drop policy if exists "app_popups_select_authenticated" on public.app_popups;
create policy "app_popups_select_authenticated"
  on public.app_popups for select
  using (auth.uid() is not null);

drop policy if exists "app_popups_admin_manage" on public.app_popups;
create policy "app_popups_admin_manage"
  on public.app_popups for all
  using (public.is_admin())
  with check (public.is_admin());

-- Carry the existing pop-up across as an every-day one, so whatever is
-- configured today keeps showing without anybody having to retype it.
--
-- Guarded on the table being empty rather than on a flag, so re-running
-- this migration cannot duplicate the row — and so it quietly does
-- nothing on a database where pop-ups have already been created.
insert into public.app_popups (
  title, body, image_url, starts_at, enabled, weekday, sort_order
)
select
  popup_title, popup_body, popup_image_url, popup_start_at,
  popup_enabled, null, 0
from public.app_config
where id = true
  and (coalesce(popup_title, '') <> '' or coalesce(popup_body, '') <> '')
  and not exists (select 1 from public.app_popups);
