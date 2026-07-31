-- Course enrolments an admin has withdrawn.
--
-- Access was previously withdrawn by dating `expires_at` in the past,
-- which relocked the course correctly but left the row as 'paid'. That
-- collides with uq_course_purchases_paid — one paid row per (user,
-- course) — so a student whose access had been removed could never buy
-- the course again: checkout refused them as already owning it, and had
-- it not, the webhook's update to 'paid' would have violated the index
-- AFTER their card was charged.
--
-- A distinct status keeps the index meaning "one ACTIVE enrolment", so a
-- repurchase inserts a new row and the withdrawn one stays on the books
-- with its own amount and payment id. has_course_access() already
-- requires status = 'paid', so nothing there needs to change.
--
-- `expires_at` keeps its own meaning: time-limited access that lapses on
-- its own. The two are independent — a row can expire, be revoked, or
-- both.

alter table public.course_purchases
  drop constraint if exists course_purchases_status_check;

alter table public.course_purchases
  add constraint course_purchases_status_check
    check (status in ('pending', 'paid', 'failed', 'refunded', 'revoked'));
