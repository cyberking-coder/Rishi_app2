-- devices: enforces one active device per account
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  device_fingerprint text not null,
  device_name text,
  platform text not null check (platform in ('android', 'ios', 'web')),
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  bound_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- One active device per user, enforced at the database level
create unique index uq_devices_one_active_per_user
  on public.devices (user_id)
  where (is_active);

create unique index uq_devices_user_fingerprint
  on public.devices (user_id, device_fingerprint);

create index idx_devices_user_id on public.devices (user_id);
create index idx_devices_last_seen on public.devices (last_seen_at);

-- RLS
alter table public.devices enable row level security;

create policy "devices_select_own_or_admin"
  on public.devices for select
  using (user_id = auth.uid() or public.is_admin());

-- Inserts/updates/deletes for devices go through SECURITY DEFINER RPCs
-- (bind_device / release_device) so race conditions on the "one active
-- device" constraint are handled atomically server-side, not by direct
-- client writes.
create policy "devices_admin_manage"
  on public.devices for all
  using (public.is_admin())
  with check (public.is_admin());

-- Atomic device binding: deactivates any existing active device for the
-- user and activates/inserts the new one in a single transaction.
create or replace function public.bind_device(
  p_device_fingerprint text,
  p_device_name text,
  p_platform text
)
returns public.devices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device public.devices;
begin
  perform 1 from public.devices
    where user_id = auth.uid() and is_active
    for update;

  update public.devices
    set is_active = false
    where user_id = auth.uid() and is_active
      and device_fingerprint <> p_device_fingerprint;

  insert into public.devices (user_id, device_fingerprint, device_name, platform, is_active)
  values (auth.uid(), p_device_fingerprint, p_device_name, p_platform, true)
  on conflict (user_id, device_fingerprint)
  do update set is_active = true, last_seen_at = now(), device_name = excluded.device_name
  returning * into v_device;

  return v_device;
end;
$$;

create or replace function public.release_device(p_device_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.devices
    set is_active = false
    where id = p_device_id and user_id = auth.uid();
$$;
