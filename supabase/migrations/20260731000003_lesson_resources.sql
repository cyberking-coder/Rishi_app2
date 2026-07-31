-- Files and links become resources attached to a lesson, rather than
-- lesson types of their own.
--
-- The previous shape made a PDF its own lesson, which put a handout on
-- equal footing with a teaching session: it counted toward the lesson
-- total, appeared in the numbered curriculum, and could be "completed".
-- A worksheet belongs *to* a lesson, not beside it — so a lesson is
-- audio, video or text again, and carries any number of attachments.

-- ---------------------------------------------------------------------------
-- 1. lesson_resources
-- ---------------------------------------------------------------------------
create table if not exists public.lesson_resources (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  title text not null,
  -- 'link' points somewhere external; the rest are files we uploaded to
  -- the public covers bucket. Kept distinct so the app can pick an icon
  -- and wording without sniffing the URL.
  resource_type text not null
    check (resource_type in ('pdf', 'image', 'file', 'link')),
  url text not null,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_lesson_resources_lesson
  on public.lesson_resources (lesson_id, position);

create trigger trg_lesson_resources_updated_at
  before update on public.lesson_resources
  for each row execute function public.set_updated_at();

alter table public.lesson_resources enable row level security;

-- Same visibility as the lesson it hangs off: if you can see the lesson,
-- you can see its attachments. Mirrors how lessons inherit from courses.
create policy "lesson_resources_select_via_lesson"
  on public.lesson_resources for select
  using (
    exists (
      select 1
      from public.lessons l
      join public.course_modules m on m.id = l.module_id
      join public.courses c on c.id = m.course_id
      where l.id = lesson_resources.lesson_id
        and (c.status = 'published' or public.is_admin())
    )
  );

create policy "lesson_resources_admin_manage"
  on public.lesson_resources for all
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- 2. Migrate any lessons that were created as a file/link
-- ---------------------------------------------------------------------------
-- Non-destructive: the payload moves into a resource row on the same
-- lesson, and the lesson itself becomes a text lesson that introduces
-- it. Nothing an admin uploaded is lost.
insert into public.lesson_resources (lesson_id, title, resource_type, url, position)
select
  l.id,
  coalesce(nullif(l.resource_name, ''), l.title),
  l.lesson_type,
  l.resource_url,
  0
from public.lessons l
where l.lesson_type in ('pdf', 'image', 'file', 'link')
  and l.resource_url is not null;

update public.lessons
   set lesson_type = 'text',
       body_markdown = coalesce(
         nullif(body_markdown, ''),
         'See the attached resource below.'
       )
 where lesson_type in ('pdf', 'image', 'file', 'link');

-- ---------------------------------------------------------------------------
-- 3. Narrow lesson_type back to the three teaching formats
-- ---------------------------------------------------------------------------
alter table public.lessons
  drop constraint if exists lessons_lesson_type_check;

alter table public.lessons
  add constraint lessons_lesson_type_check
    check (lesson_type in ('audio', 'video', 'text'));

alter table public.lessons
  drop constraint if exists chk_lesson_payload;

alter table public.lessons
  add constraint chk_lesson_payload check (
    (lesson_type = 'text' and body_markdown is not null)
    or lesson_type in ('audio', 'video')
  );

-- resource_url / resource_name stay on lessons as dead columns rather
-- than being dropped: the data has already been copied out, and dropping
-- them would break any deployed client still selecting them mid-rollout.
