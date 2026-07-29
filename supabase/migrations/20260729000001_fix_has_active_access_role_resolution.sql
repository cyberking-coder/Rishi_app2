-- Phase 0: Free / Retreat / Admin role-resolution (pure derivation layer, no
-- schema change).
--
-- Problem: `has_active_access` treated a null `access_expires_at` as
-- unlimited access, for anyone. A future self-signup free user's profile
-- gets `access_expires_at = null` from the `handle_new_user` trigger default
-- with no admin action at all — under the old logic that would silently
-- grant them unlimited premium access.
--
-- Fix: a non-null `access_expires_at` is unambiguous and always wins — it's
-- a real grant, active iff in the future, regardless of anything else (this
-- covers the "Grant N days" admin action, which only ever touches
-- `access_expires_at`, never `access_started_at`). The ambiguity only exists
-- when `access_expires_at is null` — that could mean "never granted
-- anything" (self-signup default) or "explicitly granted unlimited access".
-- `access_started_at` disambiguates that one remaining case: it's stamped by
-- every admin grant path that results in a null expiry, and is null only for
-- an account nothing has ever touched.
--
-- This is a no-op for every existing profile that has ever been granted a
-- concrete access window. A small number of legacy accounts with both
-- columns null (granted unlimited access through a path that predates this
-- fix, or genuinely never touched) may need `access_started_at` backfilled
-- by hand — see the accompanying audit query run before this migration.

create or replace function public.has_active_access(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select
       role in ('admin', 'content_manager', 'support')
       or (
         case
           when access_expires_at is not null then access_expires_at > now()
           else access_started_at is not null
         end
       )
     from public.profiles where id = p_user_id),
    false
  );
$$;

-- Reusable tri-state resolution for anything that needs the full
-- admin/retreat/free classification rather than a plain boolean (mirrors the
-- rule above; kept in sync deliberately rather than re-deriving it).
create or replace function public.resolve_user_tier(p_user_id uuid default auth.uid())
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when role in ('admin', 'content_manager', 'support') then 'admin'
    when access_expires_at is not null and access_expires_at > now() then 'retreat'
    when access_expires_at is null and access_started_at is not null then 'retreat'
    else 'free'
  end
  from public.profiles where id = p_user_id;
$$;
