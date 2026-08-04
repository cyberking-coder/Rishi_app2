-- Paid live sessions: the price moves onto the session itself.
--
-- The previous migration hung a fee on the pop-up, which made the advert
-- and the event two objects that had to be kept in step by hand — a
-- pop-up saying ₹499 and a session nobody could join, or a session with
-- no way to be paid for. A workshop IS the live session. One row, one
-- price, one join link.
--
-- The pop-up goes back to being what it always was: an advert. It gets a
-- button that opens the sessions screen, and the paying happens there,
-- next to the thing being paid for.

-- ---------------------------------------------------------------------------
-- 1. Price on the session
-- ---------------------------------------------------------------------------
alter table public.live_sessions
  -- Paise, matching courses.price_amount. Null or 0 = free to join, which
  -- is every session that exists today.
  add column if not exists price_amount int,
  add column if not exists currency text not null default 'INR',
  add column if not exists seat_limit int;

-- ---------------------------------------------------------------------------
-- 2. The join link, out of reach until it is paid for
-- ---------------------------------------------------------------------------
-- live_sessions is readable by every signed-in user — it has to be, or
-- nobody could see that a session exists. That is fine for a title and a
-- time and fatal for a paid session's join link: anyone could read the
-- URL straight from the API and walk into a meeting they had not paid
-- for. A price on a row whose payload is public is not a price.
--
-- So the link for a paid session lives here instead, behind a policy of
-- its own. Free sessions keep their link on live_sessions exactly as
-- before, which is also what keeps already-installed builds working.
create table if not exists public.live_session_join_links (
  session_id uuid primary key
    references public.live_sessions (id) on delete cascade,
  join_url text not null,
  updated_at timestamptz not null default now()
);

alter table public.live_session_join_links enable row level security;

-- Deliberately no member-facing select policy. Members reach the link
-- through live_session_join_url() below, which is security definer and
-- checks the registration. A policy here would have to re-implement that
-- check, and two copies of a rule about money is one too many.
drop policy if exists "live_session_join_links_admin"
  on public.live_session_join_links;
create policy "live_session_join_links_admin"
  on public.live_session_join_links for all
  using (public.is_admin())
  with check (public.is_admin());

-- Moves the link out of reach the moment a session is given a price, and
-- back again if the price is removed.
--
-- A trigger rather than something the admin app remembers to do: the
-- admin form writes join_url and knows nothing about this table, and a
-- rule that protects money must not depend on every future caller
-- remembering it.
create or replace function public.protect_paid_join_url()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.price_amount, 0) > 0 then
    -- Paid. Stash whatever link was supplied, then blank the public
    -- column. On an update that did not touch join_url, new.join_url is
    -- already null (blanked by a previous run) — keep the stored one.
    if new.join_url is not null and new.join_url <> '' then
      insert into public.live_session_join_links (session_id, join_url)
      values (new.id, new.join_url)
      on conflict (session_id)
        do update set join_url = excluded.join_url, updated_at = now();
    end if;
    new.join_url := '';
  else
    -- Free (or the price was removed). Put the link back where every
    -- existing client already looks for it.
    if (new.join_url is null or new.join_url = '') then
      select l.join_url into new.join_url
      from public.live_session_join_links l
      where l.session_id = new.id;
    end if;
    delete from public.live_session_join_links where session_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_live_sessions_protect_join_url on public.live_sessions;
create trigger trg_live_sessions_protect_join_url
  before insert or update on public.live_sessions
  for each row execute function public.protect_paid_join_url();

-- ---------------------------------------------------------------------------
-- 3. Registrations point at the session
-- ---------------------------------------------------------------------------
alter table public.workshop_registrations
  add column if not exists live_session_id uuid
    references public.live_sessions (id) on delete cascade;

-- Carry across anything already recorded against a pop-up. In practice
-- there is nothing — this ships in the same release — but a migration
-- that silently drops payment rows is not one worth writing.
drop index if exists public.uq_workshop_registrations_paid;

alter table public.workshop_registrations
  drop column if exists popup_id;

create unique index if not exists uq_workshop_registrations_paid
  on public.workshop_registrations (user_id, live_session_id)
  where (status = 'paid');

create index if not exists idx_workshop_registrations_session
  on public.workshop_registrations (live_session_id, status);

drop index if exists public.idx_workshop_registrations_popup;

-- ---------------------------------------------------------------------------
-- 4. Reading the link, and counting the seats
-- ---------------------------------------------------------------------------
-- The one place that decides whether somebody may have the join link.
-- Free sessions hand it over; paid ones want a paid registration. Staff
-- always get it, because somebody has to be able to host.
create or replace function public.live_session_join_url(p_session_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_price int;
  v_public_url text;
begin
  select price_amount, join_url into v_price, v_public_url
  from public.live_sessions
  where id = p_session_id and status = 'scheduled';

  if not found then
    return null;
  end if;

  if coalesce(v_price, 0) <= 0 then
    return v_public_url;
  end if;

  if not public.is_admin() and not exists (
    select 1 from public.workshop_registrations
    where live_session_id = p_session_id
      and user_id = auth.uid()
      and status = 'paid'
  ) then
    return null;
  end if;

  return (
    select join_url from public.live_session_join_links
    where session_id = p_session_id
  );
end;
$$;

revoke execute on function public.live_session_join_url(uuid) from public;
grant execute on function public.live_session_join_url(uuid) to authenticated;

create or replace function public.live_session_seats_taken(p_session_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.workshop_registrations
  where live_session_id = p_session_id and status = 'paid';
$$;

revoke execute on function public.live_session_seats_taken(uuid) from public;
grant execute on function public.live_session_seats_taken(uuid) to authenticated;
grant execute on function public.live_session_seats_taken(uuid) to service_role;

-- The pop-up's own seat/price columns are gone: it advertises, it does
-- not sell. What it keeps is a button and somewhere to send people.
drop function if exists public.workshop_seats_taken(uuid);

alter table public.app_popups
  drop column if exists price_amount,
  drop column if exists seat_limit;

alter table public.app_popups
  -- Where "Register Now" goes. An in-app route, not a URL: the button
  -- opens a screen inside the app, and letting an admin type an
  -- arbitrary link here would make the pop-up a way to send members
  -- anywhere at all.
  add column if not exists cta_route text
    check (cta_route is null or cta_route in ('/watch', '/courses', '/home'));
