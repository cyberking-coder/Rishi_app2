-- Paid workshop registration, driven from a pop-up.
--
-- A pop-up that advertises a workshop and a workshop somebody can pay for
-- are the same object from the member's side: one card, one button. So
-- the price lives on the pop-up rather than in a separate `workshops`
-- table that would then need its own admin screen, its own scheduling and
-- its own way of being shown.
--
-- What does need its own table is the registration itself. That is a
-- receipt: it has money on it, it has to survive the pop-up being edited,
-- and it is the answer to "who is coming".

alter table public.app_popups
  -- Paise, matching courses.price_amount. Subscriptions store rupees and
  -- courses store paise; the newer per-item convention is followed here
  -- so the two things a member buys one at a time agree with each other.
  -- Null or 0 means the pop-up is an announcement with no button.
  add column if not exists price_amount int,
  add column if not exists currency text not null default 'INR',
  -- Wording on the button. "Register Now" is the default; a pop-up about
  -- a retreat might say "Reserve my place".
  add column if not exists cta_label text,
  -- Null = unlimited. A workshop with a room has a ceiling.
  add column if not exists seat_limit int;

create table if not exists public.workshop_registrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  popup_id uuid not null references public.app_popups (id) on delete cascade,

  -- Paise, recorded as charged rather than looked up from the pop-up
  -- later: the price can change after the sale and the receipt must not.
  amount int not null,
  currency text not null default 'INR',

  status text not null default 'pending'
    check (status in ('pending', 'paid', 'failed', 'refunded', 'duplicate')),

  razorpay_order_id text,
  razorpay_payment_id text,

  -- Kept on the row rather than only passed to n8n. Whoever runs the
  -- workshop needs a list of who is coming and how to reach them, and
  -- that list cannot live only in a WhatsApp workflow's history.
  billing_name text,
  billing_phone text,
  billing_email text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One paid registration per person per workshop. Partial, so a failed or
-- abandoned attempt doesn't block a later successful one.
--
-- Being partial also means it CANNOT be used as an ON CONFLICT target:
-- Postgres rejects that unless the statement repeats the predicate, which
-- PostgREST's on_conflict parameter cannot express. Every writer must
-- update-then-insert. This exact trap has already cost this codebase
-- three separate bugs on course_purchases.
create unique index if not exists uq_workshop_registrations_paid
  on public.workshop_registrations (user_id, popup_id)
  where (status = 'paid');

create unique index if not exists uq_workshop_registrations_order
  on public.workshop_registrations (razorpay_order_id)
  where (razorpay_order_id is not null);

create index if not exists idx_workshop_registrations_popup
  on public.workshop_registrations (popup_id, status);

create index if not exists idx_workshop_registrations_user
  on public.workshop_registrations (user_id);

drop trigger if exists trg_workshop_registrations_updated_at
  on public.workshop_registrations;
create trigger trg_workshop_registrations_updated_at
  before update on public.workshop_registrations
  for each row execute function public.set_updated_at();

alter table public.workshop_registrations enable row level security;

-- Read your own; staff read everything. Nothing here is writable by a
-- user: rows are created by the checkout route and settled by the
-- webhook, both with the service role. A user who could insert their own
-- 'paid' row would have registered for free.
drop policy if exists "workshop_registrations_select_own_or_admin"
  on public.workshop_registrations;
create policy "workshop_registrations_select_own_or_admin"
  on public.workshop_registrations for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "workshop_registrations_admin_manage"
  on public.workshop_registrations;
create policy "workshop_registrations_admin_manage"
  on public.workshop_registrations for all
  using (public.is_admin())
  with check (public.is_admin());

-- How many seats have gone.
--
-- A function rather than a count in the app because the checkout page,
-- the order route and the admin all need the same number, and three
-- separate counts drift the moment one of them forgets to filter on
-- status.
create or replace function public.workshop_seats_taken(p_popup_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.workshop_registrations
  where popup_id = p_popup_id and status = 'paid';
$$;

revoke execute on function public.workshop_seats_taken(uuid) from public;
grant execute on function public.workshop_seats_taken(uuid) to authenticated;
grant execute on function public.workshop_seats_taken(uuid) to service_role;
