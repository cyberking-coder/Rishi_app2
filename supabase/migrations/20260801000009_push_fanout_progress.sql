-- Makes a push fan-out resumable, so a large audience can span more than
-- one function invocation.
--
-- Before this, a send was one unbounded read plus one loop inside a single
-- invocation. Two ceilings, both silent:
--
--   * PostgREST caps rows per request, so past that cap the token list was
--     quietly truncated. The function reported sent: N, failed: 0 and
--     looked perfectly healthy while most devices heard nothing.
--   * A long fan-out could run past the invocation's wall clock. Because
--     the reminder is claimed BEFORE sending, that left it marked sent
--     with only part of the audience reached, and nothing would retry.
--
-- The fix is a cursor. A send now walks the token list in chunks, records
-- how far it got, and stops cleanly when it runs low on time; the next
-- scheduled run picks the claim back up and finishes it.

-- ---------------------------------------------------------------------------
-- 1. Progress columns
-- ---------------------------------------------------------------------------
-- delivery_cursor is the LAST TOKEN sent, not a row offset. Tokens are
-- walked in sorted order and pruned as they bounce, so an offset would
-- skip devices every time a dead token ahead of the cursor was deleted
-- and shifted the rest backwards. A key can't be invalidated by a
-- deletion elsewhere in the list.
--
-- payload is the rendered notification. Stored so a resume doesn't have
-- to reconstruct the message from a session or a course that may have
-- been edited in between — the second half of an audience must get the
-- same text as the first half.
alter table public.session_reminders
  add column if not exists delivery_cursor text,
  add column if not exists completed_at timestamptz,
  add column if not exists payload jsonb;

alter table public.notification_log
  add column if not exists delivery_cursor text,
  add column if not exists completed_at timestamptz,
  add column if not exists payload jsonb;

-- ---------------------------------------------------------------------------
-- 2. Everything already sent is complete by definition
-- ---------------------------------------------------------------------------
-- Without this every historical row would look like an unfinished
-- delivery, and the first run after deploy would try to "finish" the
-- entire back catalogue of notifications.
update public.session_reminders
  set completed_at = sent_at
  where completed_at is null;

update public.notification_log
  set completed_at = sent_at
  where completed_at is null;

-- ---------------------------------------------------------------------------
-- 3. Finding work to resume
-- ---------------------------------------------------------------------------
-- Partial indexes: an unfinished delivery is rare and short-lived, so the
-- index stays tiny however large the tables grow.
create index if not exists idx_session_reminders_incomplete
  on public.session_reminders (sent_at)
  where completed_at is null;

create index if not exists idx_notification_log_incomplete
  on public.notification_log (sent_at)
  where completed_at is null;
