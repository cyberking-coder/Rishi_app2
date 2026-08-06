-- Coupons that apply to the membership, not only to courses.
--
-- The table was built when a coupon could only mean "money off a
-- course": course_id set restricted it to one course, null meant every
-- course. There was no third state, so "every course" and "anything at
-- all" were the same row and a code could not be aimed at the
-- subscription.
--
-- applies_to makes the target explicit. Existing rows default to
-- 'course', which is exactly what they already meant, so nothing that
-- works today changes behaviour.

alter table public.coupons
  add column if not exists applies_to text not null default 'course'
    check (applies_to in ('course', 'subscription', 'any')),
  add column if not exists plan_id uuid
    references public.subscription_plans (id) on delete cascade;

-- A coupon aims at one thing. Both ids set would leave the pricing code
-- picking one and silently ignoring the other, which is the sort of rule
-- nobody discovers until a customer is charged the wrong amount.
alter table public.coupons
  drop constraint if exists chk_coupon_single_target;
alter table public.coupons
  add constraint chk_coupon_single_target check (
    course_id is null or plan_id is null
  );

-- And a restriction has to match the scope it is declared in: a
-- course-scoped code cannot name a plan, and vice versa.
alter table public.coupons
  drop constraint if exists chk_coupon_target_matches_scope;
alter table public.coupons
  add constraint chk_coupon_target_matches_scope check (
    (applies_to = 'course' and plan_id is null)
    or (applies_to = 'subscription' and course_id is null)
    -- 'any' is deliberately unrestricted: a code good for everything
    -- names nothing in particular.
    or (applies_to = 'any' and course_id is null and plan_id is null)
  );

create index if not exists idx_coupons_plan on public.coupons (plan_id);

-- ---------------------------------------------------------------------------
-- Membership prices in rupees, and in INR
-- ---------------------------------------------------------------------------
-- subscription_plans.price is numeric(10,2) in RUPEES — unlike courses
-- and sessions, which are integer paise. That difference is old and the
-- checkout already reads it correctly, so it stays; the admin form and
-- the coupon code below both convert at the boundary rather than
-- migrating live pricing data underneath a running checkout.
--
-- The currency default, though, is a genuine leftover: 'USD' on a table
-- whose every row is priced in rupees. New plans created from the admin
-- would inherit it and the checkout would ask Razorpay for dollars.
alter table public.subscription_plans
  alter column currency set default 'INR';

update public.subscription_plans
   set currency = 'INR'
 where currency = 'USD';
