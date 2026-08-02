-- A second successful payment for a course the buyer already owns.
--
-- uq_course_purchases_paid permits one paid row per (user, course), so
-- writing the second payment as 'paid' violates it — which surfaced as
-- the webhook 500ing on every delivery and Razorpay retrying a payment
-- that could never be recorded. The money was taken and nothing in the
-- database showed it.
--
-- 'duplicate' keeps that payment on the books, outside the index, and
-- visibly not an entitlement: the buyer already has access from their
-- first purchase, and this row is what tells an admin a refund is owed.
--
-- Checkout does refuse a course the buyer already owns, so this is not
-- the normal path — it is the race (two tabs, a retried delivery, an
-- access grant applied between order creation and payment capture) that
-- the check cannot close.

alter table public.course_purchases
  drop constraint if exists course_purchases_status_check;

alter table public.course_purchases
  add constraint course_purchases_status_check
    check (status in (
      'pending', 'paid', 'failed', 'refunded', 'revoked', 'duplicate'
    ));
