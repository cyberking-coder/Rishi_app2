-- Phase 0: Free / Retreat / Admin role-resolution (pure derivation layer, no
-- schema change).
--
-- Problem: `has_active_access` treated a null `access_expires_at` as
-- unlimited access. That's fine today because every profile is admin-created
-- via the dashboard's `createUser`, which always stamps `access_started_at`
-- (even for a deliberate "unlimited" grant). But a future self-signup free
-- user's profile row gets `access_expires_at = null` from the `handle_new_user`
-- trigger default with no admin action at all — under the old logic that
-- would silently grant them unlimited premium access.
--
-- Fix: only treat null expiry as "unlimited" once an admin has actually
-- activated the account (`access_started_at is not null`), or the caller is
-- staff. A row that was never granted a window (the self-signup default)
-- now correctly resolves to no access instead of unlimited access.
--
-- This is a no-op for every existing profile: every current row was created
-- through `createUser`, which always sets `access_started_at`.

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
       or (access_started_at is not null
           and (access_expires_at is null or access_expires_at > now()))
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
    when access_started_at is not null
         and (access_expires_at is null or access_expires_at > now())
      then 'retreat'
    else 'free'
  end
  from public.profiles where id = p_user_id;
$$;
