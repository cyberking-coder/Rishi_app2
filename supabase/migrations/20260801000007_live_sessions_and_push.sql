-- Live sessions (Zoom) with scheduled reminders, and the push tokens
-- those reminders are delivered to.
--
-- A session is a Zoom link, a thumbnail and a time. The user taps the
-- thumbnail and lands in the meeting — so the link is the payload, not
-- decoration, and everything here exists to get someone to it at the
-- right moment.

-- ---------------------------------------------------------------------------
-- 1. live_sessions
-- ---------------------------------------------------------------------------
create table if not exists public.live_sessions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  -- Tapped to join. Not validated as a Zoom URL specifically: Zoom is
  -- what's used today, but a Meet or Teams link would work identically
  -- and rejecting one would be a rule with no purpose behind it.
  join_url text not null,
  thumbnail_url text,
  starts_at timestamptz not null,
  -- Used only to decide when the card stops reading as "live now". A
  -- session that overruns is normal, so this is a display hint rather
  -- than an end time anything enforces.
  duration_minutes int not null default 60
    check (duration_minutes > 0),
  status text not null default 'scheduled'
    check (status in ('scheduled', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_live_sessions_upcoming
  on public.live_sessions (starts_at)
  where status = 'scheduled';

create trigger trg_live_sessions_updated_at
  before update on public.live_sessions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. push_tokens
-- ---------------------------------------------------------------------------
-- One row per device per user. Keyed on the token, because that is what
-- FCM actually addresses and what it invalidates — a user_id key would
-- lose the second device, and a device_id key would go stale when the
-- OS reissues a token for the same install.
create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists idx_push_tokens_user on public.push_tokens (user_id);

-- ---------------------------------------------------------------------------
-- 3. session_reminders — what has been sent, so nothing sends twice
-- ---------------------------------------------------------------------------
-- The scheduler polls; polling means overlapping runs and retries. This
-- table is what makes that safe: the unique constraint is the guard, so
-- two runs racing on the same window produce one notification, not two.
-- Same reasoning as webhook_events on the payment side.
create table if not exists public.session_reminders (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.live_sessions (id) on delete cascade,
  -- Minutes before the start: 60, 30 or 5.
  minutes_before int not null,
  sent_at timestamptz not null default now(),
  recipient_count int not null default 0,
  constraint uq_session_reminders unique (session_id, minutes_before)
);

-- ---------------------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------------------
alter table public.live_sessions enable row level security;
alter table public.push_tokens enable row level security;
alter table public.session_reminders enable row level security;

-- Sessions are announcements: visible to any signed-in user. Cancelled
-- ones stay readable so a card can say "cancelled" rather than silently
-- vanishing from someone who was counting on it.
create policy "live_sessions_select_authenticated"
  on public.live_sessions for select
  to authenticated
  using (true);

create policy "live_sessions_admin_manage"
  on public.live_sessions for all
  using (public.is_admin())
  with check (public.is_admin());

-- A device registers its own token and nobody else's.
create policy "push_tokens_manage_own"
  on public.push_tokens for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "push_tokens_admin_read"
  on public.push_tokens for select
  using (public.is_admin());

-- Written only by the scheduler through the service role; readable by
-- admins so a missed reminder can be diagnosed from the dashboard.
create policy "session_reminders_admin_read"
  on public.session_reminders for select
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- 5. due_session_reminders — the scheduler's single question
-- ---------------------------------------------------------------------------
-- "Which sessions have crossed a reminder mark that hasn't been sent?"
--
-- The window is deliberately generous (the mark, plus anything up to
-- p_window_minutes past it) so a scheduler that runs every 5 minutes,
-- or misses a beat entirely, still catches the mark rather than stepping
-- over it. Sending a 30-minute reminder at 27 minutes is fine; sending
-- nothing is not. The unique constraint on session_reminders is what
-- keeps that generosity from producing duplicates.
create or replace function public.due_session_reminders(
  p_window_minutes int default 10
)
returns table (
  session_id uuid,
  title text,
  starts_at timestamptz,
  join_url text,
  minutes_before int
)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.title, s.starts_at, s.join_url, m.minutes_before
  from public.live_sessions s
  cross join (values (60), (30), (5)) as m(minutes_before)
  where s.status = 'scheduled'
    and s.starts_at > now()
    and s.starts_at - make_interval(mins => m.minutes_before) <= now()
    and s.starts_at - make_interval(mins => m.minutes_before)
        > now() - make_interval(mins => p_window_minutes)
    and not exists (
      select 1 from public.session_reminders r
      where r.session_id = s.id
        and r.minutes_before = m.minutes_before
    );
$$;

revoke execute on function public.due_session_reminders(int) from public, anon, authenticated;
