-- Self-service signup defaults.
--
-- handle_new_user() previously left access_expires_at null on insert, which
-- has_active_access() treats as "unlimited access" (see
-- 20260616000016_retreat_access_and_popup.sql — intentional for
-- staff/admin accounts). That was safe as long as every profile row was
-- admin-created, since the admin dashboard's createUser action always
-- immediately overwrites access_started_at/access_expires_at in a
-- follow-up update (admin/src/app/actions/users.ts).
--
-- Self-service signup has no such follow-up. Left unchanged, a
-- self-signed-up row would inherit that same null default and be
-- incorrectly treated as having unlimited premium access. This sets
-- access_started_at/access_expires_at to the moment of signup instead, so
-- a brand-new account starts with zero access (a Free User) until an
-- admin grants access or a purchase does. Admin-created accounts are
-- unaffected: their follow-up update overwrites this value immediately,
-- exactly as before this migration.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, access_started_at, access_expires_at)
  values (new.id, new.raw_user_meta_data ->> 'display_name', now(), now());
  return new;
end;
$$;
