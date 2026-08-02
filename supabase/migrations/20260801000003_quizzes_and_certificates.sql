-- Phase 5: quizzes and completion certificates.
--
-- Additive only. Courses, modules, lessons and lesson_progress are
-- untouched, so a course with no quiz behaves exactly as it does today.
--
-- Two design decisions worth stating up front, because both are load-
-- bearing for correctness rather than style:
--
--  * The correct answer never reaches the client. RLS is row-level and
--    cannot hide a column, so `quiz_options.is_correct` is withheld with
--    a column-level GRANT instead — PostgREST honours those, so a learner
--    selecting that column gets a permission error rather than the
--    answer key. Scoring therefore has to happen server-side, which is
--    what submit_quiz_attempt() is for.
--
--  * A quiz attaches to EITHER a lesson or a course, never both and
--    never neither. A lesson quiz is a checkpoint inside the material; a
--    course quiz is the final assessment gating the certificate. Keeping
--    them one table with an exclusive-or check means the scoring and
--    attempt machinery is written once.

-- ---------------------------------------------------------------------------
-- 1. quizzes
-- ---------------------------------------------------------------------------
create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references public.courses (id) on delete cascade,
  lesson_id uuid references public.lessons (id) on delete cascade,
  title text not null,
  description text,
  -- Percentage needed to pass. Stored per quiz rather than as one global
  -- setting so a gentle mid-course check and a final assessment can have
  -- different bars.
  pass_percent int not null default 70
    check (pass_percent between 1 and 100),
  -- null = unlimited retakes. A learner who fails should normally be able
  -- to study and try again; a cap exists for assessments that need one.
  max_attempts int check (max_attempts is null or max_attempts > 0),
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_quiz_owner check (
    (course_id is not null and lesson_id is null)
    or (course_id is null and lesson_id is not null)
  )
);

create index if not exists idx_quizzes_course on public.quizzes (course_id)
  where course_id is not null;
create index if not exists idx_quizzes_lesson on public.quizzes (lesson_id)
  where lesson_id is not null;

create trigger trg_quizzes_updated_at
  before update on public.quizzes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. quiz_questions / quiz_options
-- ---------------------------------------------------------------------------
create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes (id) on delete cascade,
  prompt text not null,
  -- Shown after answering, right or wrong. A quiz that only reports a
  -- score teaches nothing.
  explanation text,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_quiz_questions_quiz
  on public.quiz_questions (quiz_id, position);

create trigger trg_quiz_questions_updated_at
  before update on public.quiz_questions
  for each row execute function public.set_updated_at();

create table if not exists public.quiz_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.quiz_questions (id) on delete cascade,
  label text not null,
  is_correct boolean not null default false,
  position int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_quiz_options_question
  on public.quiz_options (question_id, position);

-- ---------------------------------------------------------------------------
-- 3. quiz_attempts
-- ---------------------------------------------------------------------------
-- One row per submission, never overwritten — a learner's history is part
-- of the record, and "best attempt" is a read-time MAX rather than a
-- mutable column that could drift.
create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  quiz_id uuid not null references public.quizzes (id) on delete cascade,
  score_percent int not null check (score_percent between 0 and 100),
  correct_count int not null default 0,
  question_count int not null default 0,
  passed boolean not null default false,
  -- {question_id: option_id} exactly as submitted, so an attempt can be
  -- reviewed later and a disputed score re-derived from the source.
  answers jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_quiz_attempts_user_quiz
  on public.quiz_attempts (user_id, quiz_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 4. certificates
-- ---------------------------------------------------------------------------
create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  -- Human-quotable and unique, so a holder can be verified from the
  -- number alone without exposing internal ids.
  certificate_number text not null unique,
  -- Snapshotted, not joined. A certificate states what was true when it
  -- was earned; renaming the course later must not silently rewrite
  -- every certificate already issued for it.
  course_title text not null,
  recipient_name text,
  issued_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint uq_certificates_user_course unique (user_id, course_id)
);

create index if not exists idx_certificates_user on public.certificates (user_id);
create index if not exists idx_certificates_course on public.certificates (course_id);

-- ---------------------------------------------------------------------------
-- 5. RLS
-- ---------------------------------------------------------------------------
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_options enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.certificates enable row level security;

-- Quizzes inherit visibility from whatever they hang off, the same
-- "check the parent" shape course_modules and lessons already use.
create policy "quizzes_select_via_parent"
  on public.quizzes for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.courses c
      where c.id = quizzes.course_id and c.status = 'published'
    )
    or exists (
      select 1
      from public.lessons l
      join public.course_modules m on m.id = l.module_id
      join public.courses c on c.id = m.course_id
      where l.id = quizzes.lesson_id and c.status = 'published'
    )
  );

create policy "quizzes_admin_manage"
  on public.quizzes for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "quiz_questions_select_via_quiz"
  on public.quiz_questions for select
  using (
    exists (select 1 from public.quizzes q where q.id = quiz_questions.quiz_id)
  );

create policy "quiz_questions_admin_manage"
  on public.quiz_questions for all
  using (public.is_admin())
  with check (public.is_admin());

create policy "quiz_options_select_via_question"
  on public.quiz_options for select
  using (
    exists (
      select 1 from public.quiz_questions qq
      where qq.id = quiz_options.question_id
    )
  );

create policy "quiz_options_admin_manage"
  on public.quiz_options for all
  using (public.is_admin())
  with check (public.is_admin());

-- Attempts are written only by submit_quiz_attempt(), never directly —
-- a client that could INSERT here could award itself 100%.
create policy "quiz_attempts_select_own_or_admin"
  on public.quiz_attempts for select
  using (user_id = auth.uid() or public.is_admin());

create policy "quiz_attempts_admin_manage"
  on public.quiz_attempts for all
  using (public.is_admin())
  with check (public.is_admin());

-- Same for certificates: issued by RPC, readable by their owner.
create policy "certificates_select_own_or_admin"
  on public.certificates for select
  using (user_id = auth.uid() or public.is_admin());

create policy "certificates_admin_manage"
  on public.certificates for all
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- 6. Hide the answer key
-- ---------------------------------------------------------------------------
-- RLS decides which ROWS are visible; it cannot withhold a column. A
-- learner needs to read the options to answer, so the row must be
-- readable — which without this would hand them is_correct as well.
-- Column-level grants are the mechanism that actually withholds it, and
-- PostgREST enforces them: selecting is_correct as a learner errors
-- instead of returning the answer.
revoke select on public.quiz_options from authenticated, anon;
grant select (id, question_id, label, position, created_at)
  on public.quiz_options to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 7. submit_quiz_attempt — the only way an attempt is ever recorded
-- ---------------------------------------------------------------------------
-- Scores server-side and returns per-question results. The client sends
-- what was chosen; it never sees, and never asserts, what was correct.
--
-- p_answers shape: {"<question_id>": "<option_id>", ...}. A question left
-- out is simply wrong, which is also how an unanswered question should
-- score.
create or replace function public.submit_quiz_attempt(
  p_quiz_id uuid,
  p_answers jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_quiz public.quizzes%rowtype;
  v_question_count int;
  v_correct_count int;
  v_score int;
  v_passed boolean;
  v_attempts_used int;
  v_attempt_id uuid;
  v_results jsonb;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_quiz from public.quizzes where id = p_quiz_id;
  if not found then
    raise exception 'Quiz not found';
  end if;

  -- Retake limit, checked before any write so a refused attempt leaves no
  -- trace and doesn't consume itself.
  if v_quiz.max_attempts is not null then
    select count(*) into v_attempts_used
    from public.quiz_attempts
    where user_id = v_user_id and quiz_id = p_quiz_id;

    if v_attempts_used >= v_quiz.max_attempts then
      raise exception 'No attempts remaining for this quiz';
    end if;
  end if;

  select count(*) into v_question_count
  from public.quiz_questions where quiz_id = p_quiz_id;

  if v_question_count = 0 then
    raise exception 'This quiz has no questions yet';
  end if;

  -- One pass over the questions, joining each to the option the learner
  -- picked. left join, so an unanswered question still produces a row and
  -- still counts against the total.
  select
    count(*) filter (where chosen.is_correct),
    jsonb_agg(
      jsonb_build_object(
        'question_id', q.id,
        'chosen_option_id', chosen.id,
        'correct_option_id', (
          select o.id from public.quiz_options o
          where o.question_id = q.id and o.is_correct
          order by o.position limit 1
        ),
        'correct', coalesce(chosen.is_correct, false),
        'explanation', q.explanation
      )
      order by q.position, q.created_at
    )
  into v_correct_count, v_results
  from public.quiz_questions q
  -- Matched as text, not cast to uuid: a malformed id in the submitted
  -- payload should score as wrong, not abort the whole submission with a
  -- cast error the learner can neither see nor fix.
  left join public.quiz_options chosen
    on chosen.question_id = q.id
   and chosen.id::text = (p_answers ->> q.id::text)
  where q.quiz_id = p_quiz_id;

  v_correct_count := coalesce(v_correct_count, 0);
  v_score := round((v_correct_count::numeric / v_question_count) * 100);
  v_passed := v_score >= v_quiz.pass_percent;

  insert into public.quiz_attempts (
    user_id, quiz_id, score_percent, correct_count,
    question_count, passed, answers
  )
  values (
    v_user_id, p_quiz_id, v_score, v_correct_count,
    v_question_count, v_passed, coalesce(p_answers, '{}'::jsonb)
  )
  returning id into v_attempt_id;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'score_percent', v_score,
    'correct_count', v_correct_count,
    'question_count', v_question_count,
    'pass_percent', v_quiz.pass_percent,
    'passed', v_passed,
    'results', coalesce(v_results, '[]'::jsonb)
  );
end;
$$;

grant execute on function public.submit_quiz_attempt(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Course completion
-- ---------------------------------------------------------------------------
-- "Complete" means every lesson done AND every quiz in the course passed
-- at least once. Both halves matter: lessons alone would certify someone
-- who scrolled past the material, and quizzes alone would certify someone
-- who never opened it.
create or replace function public.course_completion_state(
  p_user_id uuid,
  p_course_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with course_lessons as (
    select l.id
    from public.lessons l
    join public.course_modules m on m.id = l.module_id
    where m.course_id = p_course_id
  ),
  -- Every quiz belonging to this course, whether hung off the course
  -- itself or off one of its lessons.
  course_quizzes as (
    select q.id
    from public.quizzes q
    where q.course_id = p_course_id
       or q.lesson_id in (select id from course_lessons)
  )
  select jsonb_build_object(
    'lesson_count', (select count(*) from course_lessons),
    'lessons_completed', (
      select count(*) from public.lesson_progress lp
      where lp.user_id = p_user_id
        and lp.completed
        and lp.lesson_id in (select id from course_lessons)
    ),
    'quiz_count', (select count(*) from course_quizzes),
    'quizzes_passed', (
      select count(distinct qa.quiz_id) from public.quiz_attempts qa
      where qa.user_id = p_user_id
        and qa.passed
        and qa.quiz_id in (select id from course_quizzes)
    ),
    'complete', (
      (select count(*) from course_lessons) > 0
      and (select count(*) from course_lessons) = (
        select count(*) from public.lesson_progress lp
        where lp.user_id = p_user_id
          and lp.completed
          and lp.lesson_id in (select id from course_lessons)
      )
      and (select count(*) from course_quizzes) = (
        select count(distinct qa.quiz_id) from public.quiz_attempts qa
        where qa.user_id = p_user_id
          and qa.passed
          and qa.quiz_id in (select id from course_quizzes)
      )
    )
  );
$$;

grant execute on function public.course_completion_state(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. issue_certificate — idempotent, and the only writer of certificates
-- ---------------------------------------------------------------------------
-- Safe to call on every course-screen load: a second call returns the
-- certificate already held rather than minting another, so the client
-- needs no "have I claimed this yet" bookkeeping.
create or replace function public.issue_certificate(p_course_id uuid)
returns public.certificates
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing public.certificates%rowtype;
  v_state jsonb;
  v_course public.courses%rowtype;
  v_name text;
  v_number text;
  v_row public.certificates%rowtype;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_existing
  from public.certificates
  where user_id = v_user_id and course_id = p_course_id;

  if found then
    return v_existing;
  end if;

  v_state := public.course_completion_state(v_user_id, p_course_id);
  if not (v_state ->> 'complete')::boolean then
    raise exception 'Course is not complete yet';
  end if;

  select * into v_course from public.courses where id = p_course_id;
  if not found then
    raise exception 'Course not found';
  end if;

  select display_name into v_name from public.profiles where id = v_user_id;

  -- KT-<year>-<8 hex>. Short enough to read aloud, wide enough that
  -- guessing another holder's number is not worth attempting.
  v_number := 'KT-' || to_char(now(), 'YYYY') || '-' ||
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.certificates (
    user_id, course_id, certificate_number, course_title, recipient_name
  )
  values (v_user_id, p_course_id, v_number, v_course.title, v_name)
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.issue_certificate(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Public certificate verification
-- ---------------------------------------------------------------------------
-- A certificate is worth little if nobody but its holder can confirm it.
-- This returns the minimum a verifier needs and nothing more — no user
-- id, no email, no course id — so a shared certificate number leaks
-- nothing beyond what the certificate itself already states.
create or replace function public.verify_certificate(p_number text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
    when c.id is null then jsonb_build_object('valid', false)
    when c.revoked_at is not null then jsonb_build_object(
      'valid', false, 'revoked', true, 'certificate_number', c.certificate_number
    )
    else jsonb_build_object(
      'valid', true,
      'certificate_number', c.certificate_number,
      'recipient_name', c.recipient_name,
      'course_title', c.course_title,
      'issued_at', c.issued_at
    )
  end
  from (select 1) dummy
  left join public.certificates c on c.certificate_number = upper(trim(p_number));
$$;

grant execute on function public.verify_certificate(text) to anon, authenticated;
