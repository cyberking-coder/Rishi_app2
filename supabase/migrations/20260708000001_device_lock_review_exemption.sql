-- Exempt the App Review test account from the strict one-device lock.
--
-- App Store / Play Store reviewers sign in on their own devices, which differ
-- from any device the account was previously used on. The strict lock would
-- reject the reviewer's device and bounce them back to the login screen
-- (Apple rejection 2.1 "app keeps returning to login page"). We allow the
-- dedicated review account to register on any device without tripping the lock.
--
-- Ordinary user accounts are unaffected and remain strictly one-device.

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
  v_email text;
  v_is_review boolean;
begin
  -- Look up the caller's email to check the review allowlist.
  select email into v_email from auth.users where id = auth.uid();
  v_is_review := lower(coalesce(v_email, '')) in ('test@test.com');

  if not v_is_review then
    -- Standard strict lock for real users: reject a second device.
    select * into v_existing
      from public.devices
      where user_id = auth.uid() and is_active
      for update;

    if v_existing.id is not null and v_existing.device_fingerprint <> p_device_fingerprint then
      raise exception 'This account is already active on another device.'
        using errcode = 'P0001', hint = 'DEVICE_LOCKED';
    end if;
  else
    -- Review account: deactivate any other active devices so the reviewer's
    -- device becomes the active one, no matter what was registered before.
    update public.devices
      set is_active = false
      where user_id = auth.uid()
        and device_fingerprint <> p_device_fingerprint;
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
