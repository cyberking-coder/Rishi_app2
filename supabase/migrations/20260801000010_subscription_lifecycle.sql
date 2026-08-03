-- Telling people their access is about to end.
--
-- There is no auto-renewal in this system: a subscription payment is a
-- one-off that extends profiles.access_expires_at by the plan's interval.
-- Every renewal is therefore a customer deciding to buy again — which
-- makes the reminder that they are about to lose access the entire
-- renewal mechanism, not a courtesy on top of one.
--
-- Until now the only warning was an in-app banner at seven days, which
-- reaches exactly the people who were already opening the app.

-- ---------------------------------------------------------------------------
-- 1. A phone number to reach them on
-- ---------------------------------------------------------------------------
-- Checkout has always collected a phone number, passed it to Razorpay and
-- to n8n, and then thrown it away — the same mistake billing_name made,
-- and found the same way: something needed to contact a user and had
-- nothing to contact them with.
--
-- Kept on the profile rather than on the purchase, because "how do we
-- reach this person" is a fact about the person, not about one payment.
alter table public.profiles
  add column if not exists phone text;

-- ---------------------------------------------------------------------------
-- 2. due_expiry_reminders — who is about to lose access, or just has
-- ---------------------------------------------------------------------------
-- Four marks: seven days, three days and one day before, then once after
-- it lapses. The last one matters most and is the easiest to leave out —
-- somebody whose access ended yesterday is the likeliest renewal there
-- is, and until now nothing told them it had happened at all.
--
-- The reminder key includes the expiry timestamp, so renewing starts a
-- fresh cycle: the same user gets warned again before their *next*
-- expiry, without a separate "reset" step that could be forgotten.
create or replace function public.due_expiry_reminders(
  p_window_hours int default 26
)
returns table (
  user_id uuid,
  email text,
  display_name text,
  phone text,
  expires_at timestamptz,
  days_before int,
  kind text,
  reminder_key text
)
language sql
stable
security definer
set search_path = public
as $$
  -- Approaching expiry
  select
    p.id,
    u.email::text,
    p.display_name,
    p.phone,
    p.access_expires_at,
    m.days_before,
    'access_expiring'::text,
    p.id::text || ':' || m.days_before::text || ':' ||
      extract(epoch from p.access_expires_at)::bigint::text
  from public.profiles p
  join auth.users u on u.id = p.id
  cross join (values (7), (3), (1)) as m(days_before)
  where p.access_expires_at is not null
    -- Staff and admins hold open-ended access for a different reason and
    -- must never be told they are about to lose it.
    and p.role = 'user'
    and p.status = 'active'
    and p.access_expires_at > now()
    and p.access_expires_at - make_interval(days => m.days_before) <= now()
    and p.access_expires_at - make_interval(days => m.days_before)
        > now() - make_interval(hours => p_window_hours)
    and not exists (
      select 1 from public.notification_log n
      where n.kind = 'access_expiring'
        and n.key = p.id::text || ':' || m.days_before::text || ':' ||
          extract(epoch from p.access_expires_at)::bigint::text
    )

  union all

  -- Already lapsed, said once
  select
    p.id,
    u.email::text,
    p.display_name,
    p.phone,
    p.access_expires_at,
    0,
    'access_lapsed'::text,
    p.id::text || ':' ||
      extract(epoch from p.access_expires_at)::bigint::text
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.access_expires_at is not null
    and p.role = 'user'
    and p.status = 'active'
    and p.access_expires_at <= now()
    -- Only recently lapsed. Without this bound, deploying the feature
    -- would tell every account that ever expired, however long ago, that
    -- their access had just ended.
    and p.access_expires_at > now() - make_interval(hours => p_window_hours)
    and not exists (
      select 1 from public.notification_log n
      where n.kind = 'access_lapsed'
        and n.key = p.id::text || ':' ||
          extract(epoch from p.access_expires_at)::bigint::text
    );
$$;

-- The answer contains email addresses and phone numbers for every user in
-- the window, so this is the scheduler's question and nobody else's.
revoke execute on function public.due_expiry_reminders(int)
  from public, anon, authenticated;
grant execute on function public.due_expiry_reminders(int) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Reaching one user's devices
-- ---------------------------------------------------------------------------
-- Every notification so far has been an announcement to everybody. An
-- expiry notice is the first one addressed to a single person, and this
-- index is what keeps finding their devices cheap as the token table
-- grows. push_tokens already has idx_push_tokens_user; this adds the
-- sort key the fan-out walks by so the lookup stays a single index scan.
create index if not exists idx_push_tokens_user_token
  on public.push_tokens (user_id, token);
