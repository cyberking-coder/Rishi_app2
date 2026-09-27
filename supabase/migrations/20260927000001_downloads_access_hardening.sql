-- Downloads access-control hardening — audit findings A3 and A4.
--
-- A3. revoke_downloads_for_device(p_device_id uuid) is SECURITY DEFINER and
-- revokes every download row for the given device with NO ownership check
-- (unlike its sibling release_device, which scopes to auth.uid()). It is also
-- executable by anon/authenticated by default, so any signed-in user who knew
-- a victim's device UUID could POST /rest/v1/rpc/revoke_downloads_for_device
-- and purge that victim's offline downloads on their next launch.
--
-- The only legitimate caller is the admin dashboard, which invokes it through
-- the SERVICE-ROLE client (admin/src/app/actions/devices.ts:25,63,85) — never
-- an end-user session. service_role bypasses these grants, so simply removing
-- end-user EXECUTE closes the hole without changing the admin flow. (Adding an
-- `and user_id = auth.uid()` guard would instead BREAK the admin call, whose
-- auth.uid() is null.)
revoke execute on function public.revoke_downloads_for_device(uuid)
  from anon, authenticated;

-- A4. The downloads_update_own RLS policy is
--   for update using (user_id = auth.uid()) with check (user_id = auth.uid())
-- which constrains WHICH row an owner may update but not WHICH columns — RLS
-- structurally cannot, since a with-check sees only the new row. So a row's
-- owner could PATCH license_expires_at to a future date (extend an expired
-- offline licence) or rewrite encrypted_key_ref, defeating the server-side
-- expiry/revocation. The app itself only ever writes download_status +
-- downloaded_at (download_source_resolver.dart), so remove client UPDATE on
-- the two sensitive columns via a column-level GRANT (grants are column-aware
-- where RLS is not — the same technique used to lock the profile entitlement
-- columns in 20260825000001). The per-download AES key lives on-device, so
-- this is defence-in-depth on the licence window rather than the whole offline
-- DRM story; the residual (a determined owner re-marking their own row 'ready'
-- to skip the courtesy purge) is inherent to client-side offline playback.
revoke update (license_expires_at, encrypted_key_ref)
  on public.downloads from anon, authenticated;
