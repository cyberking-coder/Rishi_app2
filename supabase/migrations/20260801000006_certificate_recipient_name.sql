-- Put the buyer's real name on their certificate.
--
-- issue_certificate() read profiles.display_name and nothing else. That
-- column is empty for anyone who signed up with email/password and never
-- set a name — which is most buyers — so certificates were being issued
-- to "Student".
--
-- The name was never missing, only unsaved: checkout collects it as
-- billing_name and passes it to Razorpay and to n8n, then discards it.
-- Now it is kept on the purchase, and the certificate prefers the
-- profile name (which the person chose for themselves) and falls back to
-- what they typed when they paid.

alter table public.course_purchases
  add column if not exists billing_name text;

comment on column public.course_purchases.billing_name is
  'Name entered at checkout. Used for the completion certificate when '
  'the buyer never set a profile display name.';

-- ---------------------------------------------------------------------------
-- issue_certificate — same contract, better name resolution
-- ---------------------------------------------------------------------------
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
    -- Backfill rather than return as-is: a certificate issued before this
    -- migration carries no name, and re-opening the course screen is the
    -- natural moment to repair it. Only ever fills a blank — a name an
    -- admin has corrected by hand is never overwritten.
    if coalesce(trim(v_existing.recipient_name), '') = '' then
      select coalesce(
        nullif(trim(p.display_name), ''),
        nullif(trim(cp.billing_name), '')
      )
      into v_name
      from public.profiles p
      left join public.course_purchases cp
        on cp.user_id = v_user_id
       and cp.course_id = p_course_id
       and cp.status = 'paid'
      where p.id = v_user_id
      limit 1;

      if coalesce(trim(v_name), '') <> '' then
        update public.certificates
        set recipient_name = v_name
        where id = v_existing.id
        returning * into v_existing;
      end if;
    end if;

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

  -- Profile name first: it is what the person chose to be called. The
  -- billing name is a fallback, since it was typed for a payment form
  -- rather than for a credential.
  select coalesce(
    nullif(trim(p.display_name), ''),
    nullif(trim(cp.billing_name), '')
  )
  into v_name
  from public.profiles p
  left join public.course_purchases cp
    on cp.user_id = v_user_id
   and cp.course_id = p_course_id
   and cp.status = 'paid'
  where p.id = v_user_id
  limit 1;

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
