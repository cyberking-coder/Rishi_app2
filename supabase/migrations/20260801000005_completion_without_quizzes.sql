-- Course completion is finishing the lessons. Quizzes no longer gate it.
--
-- The quiz feature was built in 20260801000003 and then removed from
-- both the admin and the app: authoring questions was more work than the
-- courses need, and a certificate for completing the material is the
-- outcome that was actually wanted.
--
-- The quiz TABLES are deliberately left in place rather than dropped.
-- They hold no data, cost nothing dormant, and dropping them is
-- irreversible — whereas re-enabling the feature later is a UI change
-- plus restoring the quiz half of this function. A drop would turn a
-- reversible decision into a permanent one for no benefit today.
--
-- What changes here is only the arithmetic: course_completion_state()
-- stops counting quizzes, so `complete` means every lesson done. It
-- still reports quiz_count and quizzes_passed as zero so the shape of
-- the returned object is unchanged and no caller has to be edited in
-- step with this.

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
  done as (
    select count(*) as n
    from public.lesson_progress lp
    where lp.user_id = p_user_id
      and lp.completed
      and lp.lesson_id in (select id from course_lessons)
  ),
  total as (
    select count(*) as n from course_lessons
  )
  select jsonb_build_object(
    'lesson_count', (select n from total),
    'lessons_completed', (select n from done),
    -- Kept at zero rather than removed: callers read these keys, and a
    -- missing key is a null the client would have to guard against.
    'quiz_count', 0,
    'quizzes_passed', 0,
    -- A course with no lessons is never "complete" — otherwise an empty
    -- draft course would hand out certificates.
    'complete', (select n from total) > 0
                and (select n from total) = (select n from done)
  );
$$;
