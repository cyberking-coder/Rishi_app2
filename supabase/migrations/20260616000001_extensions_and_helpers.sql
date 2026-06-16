-- Extensions
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- Generic updated_at trigger function, reused by every table below
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Note: public.is_admin() is defined in the profiles migration, since it
-- depends on the profiles table existing first.
