-- Device lock applies to paying users only.
--
-- The one-device-per-account lock exists to stop paid access being shared
-- around. A free-tier account has nothing worth sharing - locking it just
-- creates support burden ("I switched phones and now I can't log in") for
-- users who haven't paid us anything yet.
--
-- New behaviour by tier (resolve_user_tier):
--   free            -> no lock. Logging in on a new device silently makes
--                      it the active one; the old device is deactivated
--                      rather than the new login being rejected.
--   retreat/admin   -> strict lock, unchanged: a second device is refused
--                      outright with DEVICE_LOCKED.
--
-- A free user who later pays becomes 'retreat' the moment the webhook sets
-- their access window, so the strict lock starts applying from their next
-- login with no extra bookkeeping - whichever device they were last on
-- stays active and becomes their locked device.
--
-- The App Review account exemption from 20260708000001 is preserved.

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
  v_enforce_lock boolean;
begin
  -- Look up the caller's email to check the review allowlist.
  select email into v_email from auth.users where id = auth.uid();
  v_is_review := lower(coalesce(v_email, '')) in ('test@test.com', 'applereview@gmail.com');

  -- Only paying/staff accounts are locked to a single device.
  v_enforce_lock := (not v_is_review)
    and public.resolve_user_tier(auth.uid()) <> 'free';

  if v_enforce_lock then
    -- Standard strict lock: reject a second device.
    select * into v_existing
      from public.devices
      where user_id = auth.uid() and is_active
      for update;

    if v_existing.id is not null and v_existing.device_fingerprint <> p_device_fingerprint then
      raise exception 'This account is already active on another device.'
        using errcode = 'P0001', hint = 'DEVICE_LOCKED';
    end if;
  else
    -- Free tier (or review account): deactivate any other active device so
    -- this one becomes active, instead of refusing the login. Keeps the
    -- one-active-device-per-user unique index satisfied.
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
