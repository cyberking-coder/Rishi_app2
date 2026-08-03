-- Notifications for new content, and a daily "start your day" audio.
--
-- The live-session reminders in 20260801000007 answer "is something
-- happening soon". This answers the two other reasons to open the app:
-- something new arrived, and it's morning.

-- ---------------------------------------------------------------------------
-- 1. published_at — when something became visible, not when it was typed
-- ---------------------------------------------------------------------------
-- Courses and audios are created as drafts and published later, sometimes
-- weeks later. created_at is therefore the wrong signal for "new": a
-- course drafted in June and published today would never be announced,
-- and one created and published in the same minute would be announced by
-- accident. Only the transition into 'published' means anything here.
alter table public.courses
  add column if not exists published_at timestamptz;

alter table public.audios
  add column if not exists published_at timestamptz;

create or replace function public.stamp_published_at()
returns trigger
language plpgsql
as $$
begin
  -- `is distinct from` rather than `<>` because OLD.status is null on
  -- insert, and null <> 'published' is null, not true — the insert case
  -- would silently never stamp.
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from 'published')
     and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_courses_published_at on public.courses;
create trigger trg_courses_published_at
  before insert or update on public.courses
  for each row execute function public.stamp_published_at();

drop trigger if exists trg_audios_published_at on public.audios;
create trigger trg_audios_published_at
  before insert or update on public.audios
  for each row execute function public.stamp_published_at();

-- Existing published rows get their creation time. Imprecise for anything
-- that sat in draft, but it is only ever compared against a lookback
-- window of a day or two, and every one of these rows is about to be
-- marked already-announced below anyway.
update public.courses
  set published_at = created_at
  where status = 'published' and published_at is null;

update public.audios
  set published_at = created_at
  where status = 'published' and published_at is null;

-- ---------------------------------------------------------------------------
-- 2. notification_log — one row per thing that has been announced
-- ---------------------------------------------------------------------------
-- Generalises what session_reminders does for live sessions: the unique
-- constraint is the guard that makes a polling scheduler safe to run
-- twice, or overlapping, or after a missed beat.
--
-- Kept as a second table rather than folding session_reminders into it.
-- The two carry different keys (a session plus a minute mark vs a content
-- id or a date), and rewriting an applied migration to merge them would
-- trade a small duplication for a real risk of a broken chain.
create table if not exists public.notification_log (
  id uuid primary key default gen_random_uuid(),
  -- 'new_course' | 'new_audio' | 'daily_audio'
  kind text not null,
  -- What was announced. A content id for the new-content kinds, a date
  -- (YYYY-MM-DD) for the daily one — which is exactly what makes "once
  -- per day" mean once per day regardless of how often the cron fires.
  key text not null,
  -- The content the notification pointed at. Null for kinds where the key
  -- is already the id; set for daily_audio, where it records which track
  -- was featured so the rotation can avoid repeating it.
  target_id uuid,
  sent_at timestamptz not null default now(),
  recipient_count int not null default 0,
  constraint uq_notification_log unique (kind, key)
);

create index if not exists idx_notification_log_target
  on public.notification_log (kind, target_id, sent_at desc);

alter table public.notification_log enable row level security;

-- Written only by the scheduler through the service role. Readable by
-- admins so "why didn't that go out" can be answered from the dashboard.
create policy "notification_log_admin_read"
  on public.notification_log for select
  using (public.is_admin());

-- The whole back catalogue is marked already-announced. Without this the
-- first cron run after deploy would push a notification for every course
-- and every audio ever published — the single worst thing this feature
-- could do, and it would be irreversible.
insert into public.notification_log (kind, key, sent_at, recipient_count)
select 'new_course', c.id::text, now(), 0
from public.courses c
where c.status = 'published'
on conflict (kind, key) do nothing;

insert into public.notification_log (kind, key, sent_at, recipient_count)
select 'new_audio', a.id::text, now(), 0
from public.audios a
where a.status = 'published'
on conflict (kind, key) do nothing;

-- ---------------------------------------------------------------------------
-- 3. due_content_announcements — what has arrived and not been announced
-- ---------------------------------------------------------------------------
-- The lookback window is a second safety net behind the log. Something
-- published a month ago and somehow missing from the log is not news, and
-- announcing it would be worse than staying quiet.
create or replace function public.due_content_announcements(
  p_lookback_hours int default 48
)
returns table (
  kind text,
  target_id uuid,
  title text,
  subtitle text,
  deep_link text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    'new_course'::text,
    c.id,
    c.title,
    c.description,
    '/course/' || c.id::text
  from public.courses c
  where c.status = 'published'
    and c.published_at > now() - make_interval(hours => p_lookback_hours)
    and not exists (
      select 1 from public.notification_log n
      where n.kind = 'new_course' and n.key = c.id::text
    )

  union all

  select
    'new_audio'::text,
    a.id,
    a.title,
    a.description,
    '/audio/' || a.id::text
  from public.audios a
  where a.status = 'published'
    -- Podcast episodes are children of a parent audio and would announce
    -- a whole series one episode at a time.
    and a.audio_type = 'track'
    and a.published_at > now() - make_interval(hours => p_lookback_hours)
    and not exists (
      select 1 from public.notification_log n
      where n.kind = 'new_audio' and n.key = a.id::text
    );
$$;

-- ---------------------------------------------------------------------------
-- 4. daily_audio_pick — the morning track
-- ---------------------------------------------------------------------------
-- Least-recently-featured first, never-featured before that, ties broken
-- at random. That rotates through the whole library on its own: no
-- curation list to maintain, no "featured" flag for someone to forget to
-- move, and a newly added track surfaces within a day rather than
-- whenever it happens to come up.
--
-- Not deterministic per day, and it doesn't need to be — the caller
-- claims the day in notification_log before it sends, so this is asked
-- once per day and the answer is recorded.
create or replace function public.daily_audio_pick()
returns table (
  id uuid,
  title text,
  description text,
  cover_art_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.title, a.description, a.cover_art_url
  from public.audios a
  left join lateral (
    select max(n.sent_at) as last_featured
    from public.notification_log n
    where n.kind = 'daily_audio' and n.target_id = a.id
  ) f on true
  where a.status = 'published'
    and a.audio_type = 'track'
  order by f.last_featured asc nulls first, random()
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- 5. Grants
-- ---------------------------------------------------------------------------
-- Both are the scheduler's questions. daily_audio_pick is harmless enough
-- read by a user, but there is no reason for one to ask it, and leaving
-- it open would invite it becoming a de-facto public "audio of the day"
-- endpoint that then can't be changed.
revoke execute on function public.due_content_announcements(int)
  from public, anon, authenticated;
grant execute on function public.due_content_announcements(int) to service_role;

revoke execute on function public.daily_audio_pick()
  from public, anon, authenticated;
grant execute on function public.daily_audio_pick() to service_role;
