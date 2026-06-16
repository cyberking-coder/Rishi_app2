-- Strict device-lock RPC: rejects login from a second device outright
-- instead of silently swapping the active device (used by the mobile
-- auth flow's first-login-registers-device requirement).
create or replace function public.register_device(
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
  v_existing public.devices;
  v_device public.devices;
begin
  select * into v_existing
    from public.devices
    where user_id = auth.uid() and is_active
    for update;

  if v_existing.id is not null and v_existing.device_fingerprint <> p_device_fingerprint then
    raise exception 'This account is already active on another device.'
      using errcode = 'P0001', hint = 'DEVICE_LOCKED';
  end if;

  insert into public.devices (user_id, device_fingerprint, device_name, platform, is_active, last_seen_at)
  values (auth.uid(), p_device_fingerprint, p_device_name, p_platform, true, now())
  on conflict (user_id, device_fingerprint)
  do update set
    is_active = true,
    last_seen_at = now(),
    device_name = excluded.device_name,
    platform = excluded.platform
  returning * into v_device;

  return v_device;
end;
$$;
