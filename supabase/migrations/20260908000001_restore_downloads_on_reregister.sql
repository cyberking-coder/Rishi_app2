-- Restore a re-registering device's revoked downloads.
--
-- WHY: the one-device lock makes "Reset device" / "Reset All Devices" a
-- routine action (every new build, and every time a tester trips the lock).
-- resetUserDevices() calls revoke_downloads_for_device(), which sets that
-- device's download rows to 'revoked'. The user then logs back in on the
-- SAME phone — register_device reactivates the same device row (matched by
-- fingerprint) — but the download rows stayed 'revoked', so the app's
-- launch-time purge deleted their offline files even though the account has
-- access and the device is active again. That is the "my downloads vanish
-- after a restart" report.
--
-- The client side is fixed too (revokedContentIds is now device-aware and
-- never deletes a copy the active device still holds). This closes the
-- server half: when a device re-registers, its own revoked downloads are
-- valid again, because the device coming back IS the authorized device.
--
-- Only 'revoked' is restored, and only for the device that is registering.
-- A device that never re-registers (a genuine swap-away) keeps its revoked
-- rows and is still purged. 'expired' is left alone — that is a real access
-- expiry, not a device-reset artefact.
--
-- This preserves the review-account exemption from
-- 20260708000001_device_lock_review_exemption.sql; the only addition is the
-- un-revoke just before returning.

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
  v_is_review := lower(coalesce(v_email, '')) in ('test@test.com', 'applereview@gmail.com');

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

  -- Restore this device's downloads that a reset had revoked. The device is
  -- active again and the account is authorized on it, so its offline files
  -- are valid — do not let the client purge them on the next launch.
  update public.downloads
    set download_status = 'ready'
    where device_id = v_device.id
      and download_status = 'revoked';

  return v_device;
end;
$$;
