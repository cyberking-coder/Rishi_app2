-- Chat assistant: the in-app guide that answers "how do I meditate?"
-- and "which order should I play these in?".
--
-- Three pieces, and the split between them is deliberate:
--
--   chat_messages      the conversation, so it survives a reinstall and
--                      follows the person to a second device
--   chat_quota()       what stops an LLM endpoint from being an open
--                      invoice — everybody gets a daily allowance
--   chat_catalogue()   the library, identical for every caller
--   chat_user_context() this caller's tier, purchases and history
--
-- The last two are separate functions rather than one, because the
-- catalogue is the same bytes for everyone and is therefore the part the
-- model provider can cache across users. Folding the user's progress
-- into it would make every request a unique prefix and multiply the cost
-- of the whole feature by roughly ten.

-- ---------------------------------------------------------------------------
-- chat_messages
-- ---------------------------------------------------------------------------
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  created_at timestamptz not null default now()
);

-- Both reads this table needs: "the last N of this conversation" and
-- "how many did they send today". Descending because the recent end is
-- the only end anything asks for.
create index if not exists idx_chat_messages_user_recent
  on public.chat_messages (user_id, created_at desc);

alter table public.chat_messages enable row level security;

-- No update policy at all. A message that has been sent to the model and
-- answered is a record of what happened; editing it after the fact would
-- leave the reply attached to a question nobody asked.
create policy "chat_messages_select_own"
  on public.chat_messages for select
  using (user_id = auth.uid());

create policy "chat_messages_insert_own"
  on public.chat_messages for insert
  with check (user_id = auth.uid());

-- Clearing the conversation is the user's to do, and theirs alone —
-- admins deliberately excluded here. Someone asking a meditation app
-- about their insomnia or their grief has not agreed to it being staff
-- reading material.
create policy "chat_messages_delete_own"
  on public.chat_messages for delete
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- chat_quota — the daily allowance
-- ---------------------------------------------------------------------------
-- Counted from the messages themselves rather than from a separate
-- counter table. One source of truth, nothing to drift, and no reset job
-- to fail silently at midnight: the window moves on its own.
--
-- The day is an IST day, not a UTC one. A UTC boundary rolls over at
-- 05:30 in the morning here, which would hand somebody a fresh
-- allowance in the middle of their sitting and cut another off at
-- breakfast.
create or replace function public.chat_quota(p_limit int default 20)
returns table (used int, allowance int, resets_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  with window_start as (
    select (date_trunc('day', now() at time zone 'Asia/Kolkata'))
             at time zone 'Asia/Kolkata' as from_ts
  )
  select
    count(*)::int as used,
    p_limit as allowance,
    (select from_ts + interval '1 day' from window_start) as resets_at
  from public.chat_messages m, window_start w
  where m.user_id = auth.uid()
    and m.role = 'user'
    and m.created_at >= w.from_ts;
$$;

revoke execute on function public.chat_quota(int) from public;
grant execute on function public.chat_quota(int) to authenticated;

-- ---------------------------------------------------------------------------
-- chat_catalogue — what the assistant is allowed to recommend
-- ---------------------------------------------------------------------------
-- Without this the model answers "which meditation should I start with?"
-- with a confident, well-written, entirely invented track name. Grounding
-- it in the real library is the difference between a guide and a
-- plausible liar.
--
-- Security definer and identical for every caller: it returns only
-- published rows, which is exactly what RLS already lets any signed-in
-- user select. Nothing is exposed here that a browse screen doesn't
-- already show.
create or replace function public.chat_catalogue()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'audios', coalesce((
      select jsonb_agg(a)
      from (
        select
          au.id,
          au.title,
          -- Trimmed hard. A catalogue of two hundred full descriptions
          -- costs more to send than it adds — the model needs enough to
          -- tell two tracks apart, not the marketing copy.
          left(regexp_replace(coalesce(au.description, ''), '\s+', ' ', 'g'), 180)
            as summary,
          nullif(au.artist, '') as artist,
          case when au.duration_seconds is null then null
               else round(au.duration_seconds / 60.0)::int end as minutes,
          au.is_premium as premium,
          coalesce((
            select array_agg(c.name order by c.name)
            from public.audio_categories ac
            join public.categories c on c.id = ac.category_id
            where ac.audio_id = au.id
          ), '{}') as categories
        from public.audios au
        where au.status = 'published'
        order by au.created_at desc
        limit 120
      ) a
    ), '[]'::jsonb),
    'courses', coalesce((
      select jsonb_agg(c)
      from (
        select
          co.id,
          co.title,
          left(regexp_replace(coalesce(co.description, ''), '\s+', ' ', 'g'), 240)
            as summary,
          co.is_premium as premium,
          (select count(*) from public.lessons l
             join public.course_modules m on m.id = l.module_id
            where m.course_id = co.id) as lessons
        from public.courses co
        where co.status = 'published'
        order by co.sort_order, co.created_at
        limit 60
      ) c
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.chat_catalogue() from public;
grant execute on function public.chat_catalogue() to authenticated;

-- ---------------------------------------------------------------------------
-- chat_user_context — who is asking
-- ---------------------------------------------------------------------------
-- Kept small on purpose. It is the part of the prompt that differs per
-- request, so every field here is paid for on every message; it earns
-- its place only if it changes the answer. Name, tier and what they have
-- actually listened to do. A full history would not.
create or replace function public.chat_user_context()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'name', (
      select nullif(trim(coalesce(p.display_name, '')), '')
      from public.profiles p where p.id = auth.uid()
    ),
    'tier', public.resolve_user_tier(auth.uid()),
    'has_access', public.has_active_access(auth.uid()),
    'access_expires_at', (
      select p.access_expires_at from public.profiles p where p.id = auth.uid()
    ),
    'recent', coalesce((
      select jsonb_agg(r)
      from (
        select
          au.title,
          wh.completed,
          case when wh.progress_seconds is null then null
               else round(wh.progress_seconds / 60.0)::int end as minutes_in,
          -- A date, not a timestamp: "three days ago" is the only
          -- resolution any answer here is going to use.
          wh.last_watched_at::date as on_date
        from public.watch_history wh
        join public.audios au on au.id = wh.audio_id
        where wh.user_id = auth.uid()
          and wh.audio_id is not null
        order by wh.last_watched_at desc
        limit 15
      ) r
    ), '[]'::jsonb),
    'finished_count', (
      select count(*) from public.watch_history
      where user_id = auth.uid() and audio_id is not null and completed
    ),
    'owned_courses', coalesce((
      select array_agg(co.title order by co.title)
      from public.course_purchases cp
      join public.courses co on co.id = cp.course_id
      where cp.user_id = auth.uid()
        and cp.status = 'paid'
        and (cp.expires_at is null or cp.expires_at > now())
    ), '{}')
  );
$$;

revoke execute on function public.chat_user_context() from public;
grant execute on function public.chat_user_context() to authenticated;
