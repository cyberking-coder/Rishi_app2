-- Stop a user granting themselves access by editing their own profile.
--
-- ─────────────────────────────────────────────────────────────────────
--  SECURITY FIX. Read this before relaxing anything below.
-- ─────────────────────────────────────────────────────────────────────
--
-- THE HOLE
--
-- `profiles_update_own` (20260616000002_profiles.sql) permits:
--
--     using (id = auth.uid())
--     with check (id = auth.uid() and role = 'user')
--
-- That constrains WHICH ROW may be updated, and that `role` may not be
-- escalated. It says nothing about the other columns, and RLS has no
-- way to say "this column may not change" — a WITH CHECK sees only the
-- new row, never the old one, so it cannot compare them.
--
-- Meanwhile has_active_access() (20260729000001) decides entitlement by
-- reading two of those unconstrained columns:
--
--     case when access_expires_at is not null then access_expires_at > now()
--          else access_started_at is not null end
--
-- So any signed-in user could unlock the entire premium library with one
-- PostgREST call against their own row, using nothing but the anon key
-- that ships inside the app:
--
--     PATCH /rest/v1/profiles?id=eq.<their own uid>
--     { "access_expires_at": "2099-01-01T00:00:00Z" }
--
-- RLS passes: the row is theirs and `role` is untouched. Nothing else
-- was checking. No payment involved.
--
-- THE FIX
--
-- Postgres grants ARE column-aware even though RLS is not, so the
-- restriction goes there. `authenticated` keeps UPDATE on exactly the
-- two columns a person legitimately edits about themselves, and loses
-- it everywhere else. An attempt to write any other column now fails
-- with a permission error before RLS is even consulted.
--
-- WHAT THIS DELIBERATELY DOES NOT BREAK
--
--   * The Razorpay webhook grants access with the SERVICE ROLE, which
--     bypasses both RLS and column grants. Untouched.
--   * Every admin mutation in admin/src/app/actions/users.ts goes
--     through createAdminClient(), also service role. Untouched.
--   * The app's only user-session write to profiles is display_name
--     (auth_remote_datasource.dart, setting it from the signup form),
--     which is still granted below.
--
-- The `profiles_admin_update_any` RLS policy is left in place. It is
-- now unreachable for a staff member using an ordinary session, because
-- the column grant is checked first — but no code path depends on it,
-- since the dashboard uses the service role, and leaving it costs
-- nothing while removing it would be a second behaviour change bundled
-- into a security fix.

-- anon has no business updating profiles at all: auth.uid() is null for
-- an anonymous request, so `id = auth.uid()` could never match anyway.
-- Revoked for the sake of saying so rather than relying on that.
revoke update on public.profiles from anon;

revoke update on public.profiles from authenticated;

grant update (display_name, avatar_url) on public.profiles to authenticated;

comment on table public.profiles is
  'Entitlement columns (access_started_at, access_expires_at, '
  'subscription_tier, role, status) are writable ONLY by the service '
  'role. See 20260825000001 — a column-level grant, not an RLS policy, '
  'because RLS cannot restrict which columns an update touches.';
