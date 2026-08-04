# Anurag Rishi Meditation App — Project Log

Complete record of everything built, fixed, and configured across the mobile app, admin dashboard, and Supabase backend.

**If you are an AI picking up this project**: read this whole file before touching code. Section 7 explains the LMS/payments work added on top of the original app (also described in `README.md`, which is the forward-looking roadmap this log tracks progress against) — and ends with a bug-fix chronology that is the most useful part of this document, because almost every entry in it is a trap the code alone does not reveal. Section 9 explains the folder structure in plain language. Section 10 lists exactly what's unfinished right now, including operational landmines that have each cost a full round of testing. Section 11 says how many users this can carry as it stands, and which limit gives way first.

---

## 1. Foundation & Architecture

### Database (Supabase PostgreSQL)
- Full schema migrations: `users`, `profiles`, `devices`, `audios`, `categories`, `audio_categories`, `content_assets`, `entitlements`, `watch_history`, `downloads`, `app_config`
- Row Level Security (RLS) on every table
- `register_device` RPC — strict one-device-per-account lock; blocks login from a second device
- `has_active_access(user_id)` RPC — server-side access window check (used by edge functions)
- `upsert_watch_progress` RPC — tracks per-user listen progress
- `revoke_downloads_for_device` RPC — bulk-revokes offline downloads when a device is reset

### Supabase Edge Functions (Deno)
- **`issue-audio-license`** — signs a Cloudflare R2 URL for streaming; enforces device lock + access window + entitlement checks before returning URL
- **`issue-playback-license`** — same for video (quality ladder)
- **`issue-upload-url`** — signs a presigned PUT URL for admin audio uploads to R2

(Three more edge functions were added later for payments — see Section 7.)

### Cloudflare R2
- Private bucket for all audio files
- AES-256-CTR encryption for offline downloaded files
- Signed URL TTL extended to 1 hour for large uploads
- `presignGet` shared helper used by all edge functions

---

## 2. Flutter Mobile App

### Authentication
- Clean architecture: `AuthRepository` → `AuthRemoteDataSource` → Supabase Auth
- `signInAndRegisterDevice` — signs in then immediately calls `register_device` RPC
- Device lock: if account already active on a different device, login is rejected with a clear error message
- Show/hide password toggle on the login screen (eye icon)
- Forgot password flow (sends Supabase reset email)
- **(Added later)** Self-service email/password signup, Google Sign-In — see Section 7, Phase 1

### Home Screen
- Greeting with time-of-day (Good Morning / Afternoon / Evening)
- Featured audio grid (2-column)
- Recently Added grid
- Categories row (chips linking to browse)
- Continue Listening horizontal scroll (resumes from last position)
- Access expiry banner if ≤7 days remain
- Navigates to `/now-playing` on any audio tap
- **(Added later)** Per-item premium lock badges + "Get Access Now" checkout flow for free-tier users — see Section 7, Phases 2-3

### Now Playing Screen
- Background audio via `audio_service` + `just_audio`
- Playback survives screen lock and backgrounding (OS media notification)
- Play / Pause / Skip Prev / Skip Next controls
- Seek bar with continuous position stream (updates every 200ms)
- Duration display: `mm:ss` for short tracks, `h:mm:ss` for ≥1 hour
- Playback speed selector (0.75× – 2.0×)
- Sleep timer (pause after N minutes; live countdown)
- Download button: starts download, shows live progress ring, pause/resume/delete
- Listen progress saved to Supabase every 10 seconds and on pause/stop

### Offline Downloads
- Encrypted with AES-256-CTR before hitting disk
- Local decrypting proxy on 127.0.0.1 streams bytes to `just_audio` for offline playback
- Resumable downloads: paused on app close, resumed on next open
- Downloads purged automatically when access expires or device is revoked
- Download screen lists all offline tracks with status (queued / downloading / done / failed)
- Offline player for playing downloaded content without network

### Profile Screen
- Shows display name, email, avatar initial
- Subscription status with renewal/cancellation date
- Registered device(s) — green dot on current device
- Downloads count (linked to downloads screen)
- Logout with confirmation dialog
- **(Fixed later)** Plan label used to always hardcode "Premium Member" for every user — now correctly shows Free / Premium / Staff based on real tier, see Section 7, Phase 2

### Access Window System
- `access_expires_at` on each user's profile row
- `has_active_access()` checked server-side in every edge function — device clock changes cannot bypass it
- In-app access expiry screen shown when window lapses **(removed later — replaced by per-item locking, see Phase 2)**
- Next Event popup — configurable timed popup with image, title, body (admin-controlled)
- Popup image: scrollable, full image shown with `BoxFit.contain`, max 320px height

### App Infrastructure
- `go_router` with auth-guard redirects (`/login` ↔ `/home`)
- `flutter_riverpod` for all state
- `AppShell` scaffold with bottom navigation (Home / Downloads / Profile)
- `SoftBackground` — ambient glow blobs (violet/indigo/pink) on dark canvas
- Adaptive launcher icon (headphones foreground, dark purple background)
- `FLAG_SECURE` — prevents screenshots in recent-apps switcher
- R8 obfuscation enabled for release builds
- Release keystore wired in `key.properties` (gitignored)
- Resilient boot: AudioService or download init failures no longer black-screen the app

---

## 3. Admin Dashboard (Next.js + Tailwind + Supabase SSR)

### Users Table
- Lists all users with: Name, Email, Role, Tier, Status, Access window, Joined date
- **`•••` Actions menu** per user:
  - **Reset device** — deactivates all active devices so user can register fresh on next login
  - Grant 30 / 7 / Custom days of access
  - Test access: expire in 5 or 10 minutes (for QA)
  - End access now
  - Activate / Suspend / Ban
- **Reset All Devices** button in page header — bulk-resets every active device across all users (used after shipping a new build)
- **(Fixed later)** Access column now shows "Free" instead of "Unlimited" for accounts that were never actually granted anything — see Section 7, Phase 0

### Audios / Videos Tables
- Lists all audios/videos with cover thumbnail, title, artist, duration, status
- Upload audio: file picker → presigned R2 PUT URL → upload with live progress bar
- Per-audio cover image upload
- Set `direct_url` for test-mode (bypasses R2 signing pipeline)
- Publish / unpublish audio
- **(Added later)** "Mark free/premium" toggle — previously `is_premium` could only be set once at upload time, see Section 7, Phase 2

### Categories
- Create and manage categories
- Assign audios to categories (many-to-many via `audio_categories`)

### Devices
- View all registered devices per user
- Deactivate individual devices

### Next Event Popup Config
- Toggle popup on/off
- Set show-from date (date picker) and time (time picker) separately
- Set title, body text
- Upload popup image (file picker, full image shown in preview)
- Changes reflect in app immediately on next load

### Analytics
- Basic usage stats (placeholder for future metrics)

### Checkout (added later)
- Public `/checkout/[planId]` page — NOT part of the admin dashboard proper, no login required. This is where end users (free-tier app users) land after tapping "Get Access Now" in the mobile app, to pay via Razorpay. See Section 7, Phase 3.

---

## 4. Bug Fixes Chronology (original app, pre-LMS work)

| Fix | What was broken |
|-----|----------------|
| Popup image cropped | Changed `BoxFit.cover` + fixed height to `BoxFit.contain` + `ConstrainedBox(maxHeight: 320)` inside `SingleChildScrollView` |
| Show/hide password | Login field had no toggle; added `StatefulWidget` with eye icon |
| Downloads screen stuck loading | `watchTasks()` stream didn't seed initial snapshot; fixed with `yield _sortedTasks()` |
| Offline player stuck loading | Simultaneous playback isolation fixed; `cleartext` loopback proxy permitted in `network_security_config.xml` |
| Offline download crash | `offline/` directory not created before first manifest write |
| Now Playing progress bar frozen | Switched to continuous `positionStream` + `durationStream` instead of discrete events |
| R2 presign broken | `X-Amz-Expires` must be in query string, not headers |
| Audio license MP3 fallback | Edge function only accepted `audio_hls`; added `audio_mp3` fallback |
| Duration display for long tracks | Was always showing `mm:ss`; now shows `h:mm:ss` when ≥1 hour |
| Build black-screen on audio init fail | `AudioService.init` failure now caught; falls back to plain handler so login screen still loads |
| Slider type error | `clamp()` returns `num` not `double`; added `.toDouble()` |
| AGP/Gradle/Kotlin version bump | Bumped to AGP 8.9.1, Gradle 8.12, Kotlin 2.1.0 for Flutter SDK 36 compatibility |
| Kotlin incremental cache crash on Windows | Project on `D:` drive, pub cache on `C:` drive → Kotlin cross-drive path error; fixed with `kotlin.incremental=false` in `gradle.properties` |
| `_flushProgress` crashing offline | Network error on progress save was propagating; wrapped in try-catch (best-effort) |

See Section 7 for the bug-fix chronology of the LMS/payments work (Phases 0-5).

---

## 5. Known Operational Procedures

### When a user can't log in / audio won't play ("already active on another device")
1. Admin panel → Users → `•••` on that user → **Reset device**
2. User logs out and back in on their phone
3. Fresh login runs `register_device` RPC → phone is now the active device

### After shipping a new APK to all users
1. Admin panel → Users page → **Reset All Devices** button
2. All users must log out and log back in once
3. Their devices re-register on next login

### Test user audio not playing (access shows Unlimited, status active)
- Check if that account has an **old device row** with `is_active = true` from a different emulator/device
- Fix: Reset device via admin → log out → log back in

### Extending / revoking access
- Admin panel → Users → `•••` → Grant days / End access now
- `access_expires_at = null` **and** `access_started_at` set means unlimited (staff/admin accounts, or a manually-granted lifetime user)
- `access_expires_at = null` **and** `access_started_at` also null means the account was never granted anything — a genuine free-tier user (see Phase 0 below for why this distinction matters)
- `access_expires_at` past → free-tier behavior kicks in (locked content shows a lock badge; audio/video edge functions block premium plays) — see Phase 2

---

## 6. Store Submission Status

- **Google Play**: Account in setup (DUNS number required for Organisation account — use Individual account to avoid DUNS)
- **Apple App Store**: Requires Mac for Xcode build + $99/year Apple Developer account
- APK release build: signed with keystore in `key.properties` (gitignored, keep backed up separately)
- App version: check `pubspec.yaml` → `version:` field before each store submission

---

## 7. LMS Integration — Phases 0 through 5

This is the work described in `README.md` (the LMS/payments roadmap). Phases 0-3a were built in one extended session; phases 3b, 4 and 5 in a second. Each was tested on a real device before moving to the next, except Phase 5 — see Section 10. All of it lives on the git branch `claude/repo-structure-overview-vt36iu` — **check whether this has been merged to `main` yet** before assuming it's live in production.

### Phase 0 — Free / Retreat / Admin role resolution (no schema change)

**The problem**: before this phase, *every* user was admin-created, and admin-creation always explicitly set an access window. `has_active_access()` treated a `null` `access_expires_at` as "unlimited access" for anyone. That was safe only because nothing ever produced a `null` expiry except a deliberate admin choice. Once self-signup was going to exist (Phase 1), a brand-new free user's profile would *also* get `null` expiry from the database's default trigger — which, under the old logic, would have silently granted them unlimited premium access.

**The fix**: `access_started_at` (a column that already existed) is only ever set by an actual admin grant action. A `null` `access_expires_at` now only means "unlimited" if `access_started_at` is also set; otherwise it means "never granted anything" → free tier. This is implemented in two SQL functions:
- `has_active_access(user_id)` — boolean check, used by the edge functions
- `resolve_user_tier(user_id)` — returns `'admin' | 'retreat' | 'free'`, the full tri-state

Both were mirrored in application code so the UI agrees with the server:
- Mobile: `AccessState.tier` (in `features/access/domain/access_state.dart`)
- Admin: `resolveTier()` (in `admin/src/lib/access.ts`)

**Migration**: `supabase/migrations/20260729000001_fix_has_active_access_role_resolution.sql`

**A real bug found mid-rollout**: the first version of this fix required `access_started_at` to be set for *any* active access — but the admin's "Grant N days" button only ever touches `access_expires_at`, never `access_started_at`. This would have wrongly downgraded real paying/granted users to "free." Fixed by trusting `access_expires_at` directly whenever it's non-null, and only falling back to `access_started_at` when `access_expires_at` is null (the one genuinely ambiguous case). 18 legacy accounts with both columns null were manually confirmed as real admin-granted-unlimited users and backfilled with `access_started_at = created_at`.

### Phase 1 — Self-service signup + Google Sign-In

- New `/signup` screen (`features/auth/presentation/screens/signup_screen.dart`), reusing the existing login screen's widgets and the forgot-password screen's "show a success state" pattern. Handles both possible Supabase configurations (email confirmation required vs. immediate session).
- **Google Sign-In** via the native `google_sign_in` package + Supabase's `signInWithIdToken` (not a browser redirect — avoids needing to build deep-link handling, which didn't exist in this app). Available on both login and signup screens (same action either way).
- Removed the old "How to get access" contact-us dialog from the login screen; replaced with the signup link and Google button.
- Real email regex validation (previously just checked for `@`); new-password validation requires 8+ characters with a letter, a number, and a symbol (existing passwords under looser rules aren't retroactively invalidated).
- **No database changes needed** — the `handle_new_user` trigger already defaulted new rows to `role='user'`, `subscription_tier='free'`, which (thanks to Phase 0) now correctly resolves to free tier automatically.

**Bugs found and fixed during this phase**:
| Bug | Fix |
|---|---|
| Signing up with an email that already has an account (e.g. created via Google) silently sent no email and showed a misleading "check your email" screen | Supabase returns an empty `identities` array in this case — now detected and surfaced as a proper "already registered" error |
| Logging out only cleared the Supabase session, never the cached Google account — user could never switch Google accounts after logout | `signOut()` now also calls `GoogleSignIn().signOut()` |
| `ApiException: 10` (DEVELOPER_ERROR) on Google Sign-In | Debug builds use package name `com.knowthyself.app.debug` (via `applicationIdSuffix`) and are signed with the local machine's debug keystore — both differ from the release config. Needed a **second** Android OAuth client in Google Cloud Console registered specifically for the debug package name + debug keystore SHA-1. |

**External setup required** (see the config placeholder files for exact instructions): `mobile_app/lib/core/config/google_auth_config.dart` (Web + iOS client IDs), `mobile_app/ios/Runner/Info.plist` (`GIDClientID` + URL scheme), Google Cloud Console (Web/Android/iOS OAuth clients), Supabase Dashboard → Authentication → Providers → Google.

### Phase 2 — Content gating for free-tier users

**The problem**: `home_screen.dart` had a full-screen "your access has ended" block that fired whenever `access.isExpired` was true. That check meant "no active window" — which, before Phase 1, only ever meant a lapsed retreat grant. After Phase 1, it also matched every legitimate free-tier user, who would see **zero content at all**, not even free-marked items.

**The fix**: replaced the full-screen block with per-item gating.
- Every content card checks `audio.isPremium && !access.hasAccess` → if locked, shows a small lock badge (`PremiumLockBadge` widget) instead of hiding the item.
- Tapping a locked item shows a dialog instead of attempting playback (later extended into the real "Get Access Now" checkout flow in Phase 3).
- Applied consistently across the home screen (daily card, featured row) and the browse/search screen (previously had no gating awareness at all).
- The "N days left" pill now only shows for an active retreat window, not forever for a free user whose old expiry is in the past.
- Admin dashboard: added a "Mark free/premium" toggle to the audios/videos row menu — `is_premium` could previously only be set once, at upload time.
- **Fixed a hardcoded bug found by testing**: the profile screen's "Premium Member" label and Subscription row always showed "Premium" for literally every user, because it fell back to a hardcoded string whenever the (entirely unpopulated) `subscriptions` table had no row for that user — which was always. Now derives the label from the real access tier.

**A second, more serious bug found by testing**: even after the client-side fix above, a free user still got "Your access period has ended" (403) when trying to play *free* content. The two license edge functions (`issue-audio-license`, `issue-playback-license`) ran the `has_active_access` check **unconditionally, before even looking at whether the content was premium** — a leftover from the old world where all content was effectively premium. Fixed by moving that check inside the existing `if (audio.is_premium)` block, so free content only ever requires being logged in + not device-locked.

Video content itself was left untouched — there's still no video playback UI anywhere in the app (that's a future phase), so there was nothing to gate.

### Phase 3a — Razorpay payments core

**Scope decision, made explicitly rather than assumed**: this pass ships **blanket-subscription purchases only**, not per-item content purchases — individual audios/videos have no `price` column, only `subscription_plans` does. The `entitlements` table (for future per-item purchases) is untouched, nothing is foreclosed. Also: what's called a "subscription" here is a **manually-renewed grant**, not true Razorpay Subscriptions/autopay (a much bigger integration with mandates) — a successful payment grants N days of access (N = the plan's billing interval), same mechanism the admin's "Grant N days" button already uses, and the user pays again when it lapses.

**The seeded plan**: "Rishi Mode", ₹199/month, in `supabase/migrations/20260730000001_payments_phase3.sql`.

**New pieces**:
- `webhook_events` table — replay-protection for the payment webhook (a redelivered event is a no-op, not a second grant).
- `_shared/checkout_token.ts` (edge functions) — mints a short-lived (15 min) HMAC-signed token identifying `{user, plan}` to the external checkout page. Nothing like this existed before; the app had no way to identify a user to a web page without a second login.
- `mint-checkout-token` (edge function) — the mobile app calls this to get a checkout link.
- `razorpay-webhook` (edge function) — **the only place access is ever actually granted**. Verifies the Razorpay signature (HMAC-SHA256 over the raw body, constant-time compare), checks `webhook_events` for a replay, then on `payment.captured` sets `profiles.access_expires_at` (same field every other grant mechanism uses) and records `subscriptions`/`payments` rows. Uses the Supabase **service-role key** — the first function in this codebase to need it, since Razorpay's server has no user JWT to forward and RLS blocks these table writes from anyone but an admin or service_role.
- Admin app: new public `/checkout/[planId]` page + `/api/checkout/create-order` route. Protected by the checkout token, not a Supabase login — deliberately exempted from the admin app's blanket "redirect anyone unauthenticated to /login" middleware, since the checkout page's whole audience is anonymous mobile app users, not admin staff. The client-side Razorpay success callback is purely cosmetic (shows "Payment received"); it never grants anything itself — only the webhook does, since a client-side callback runs in the payer's own browser and can't be trusted.
- Mobile: `url_launcher` opens the checkout link in an **external browser** (never in-app), matching Apple/Google's requirement to route digital-content payments outside their in-app purchase systems if you don't want to give them a cut. The premium-lock dialog's "Get Access Now" button now performs this flow, with a text fallback (the old contact-us message) if anything fails. Home screen now also re-checks access when the app resumes from background (not just on screen mount), so a completed payment unlocks promptly when the user returns from the browser.

**Bugs found and fixed while wiring this up end-to-end on a real device**:
| Bug | Fix |
|---|---|
| "Get Access Now" silently failed | Android 11+ restricts which apps' intents you can see by default (package visibility). `url_launcher` couldn't find any browser to hand the URL to. Added a `<queries>` block to `AndroidManifest.xml`. |
| `DataError: Key length is zero` in `mint-checkout-token` | `CHECKOUT_TOKEN_SECRET` was set to an empty value in Supabase's function secrets — re-set it to the actual generated secret. |
| Checkout page redirected to the admin `/login` screen | The admin app's Vercel deployment hadn't actually picked up the latest code — clicking "Redeploy" on an old deployment card rebuilds that same old commit, it doesn't pull the latest git commit. Needed to check the Deployments tab for a fresh build of the current commit. |
| Checkout page asked for a **Vercel** login (not the app's own login) | Vercel's own "Deployment Protection" setting puts preview deployments behind a Vercel-account login wall by default. Turned off in Vercel → Settings → Deployment Protection. |
| Checkout URL kept breaking across pushes | The Vercel preview URL used during testing (`rishi-app2-<hash>-...vercel.app`) is tied to one specific deployment and changes on every push. `mobile_app/lib/core/config/checkout_config.dart` needs updating each time, until this branch is merged to `main` (or set as the Vercel production branch) so the stable production domain can be used instead. |

**Bug found and fixed after further testing**: the full flow — tap "Get Access Now" → checkout page → Razorpay test payment completes → "Payment received" shown → return to app — worked, except the content did not actually unlock. Root cause: `razorpay-webhook` read `user_id`/`plan_id` off `payment.notes`, but those notes were only ever set on the Razorpay **order** at creation time (`admin/src/lib/razorpay.ts`) — Checkout.js never re-passes `notes` when opening the payment modal, so `payment.notes` arrived empty and the webhook 400'd silently (from the user's perspective — the payment itself still showed as successful, since that part is genuinely independent of the webhook). Fixed by having the webhook fetch the order directly from Razorpay's API (`fetchRazorpayOrderNotes` in `_shared/razorpay.ts`) using `payment.order_id`, with `payment.notes` kept only as a fallback. **This requires `RAZORPAY_KEY_ID` to now also be set as a Supabase Edge Function secret** (previously only needed by the admin app) — see Section 8.

**Required external setup** (all done during this session, but written here so a fresh environment can be reconstructed):
- Razorpay: test-mode API key ID + secret; a registered webhook (`payment.captured` event) pointing at the deployed `razorpay-webhook` function, with its own webhook secret.
- Supabase Edge Function secrets: `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `CHECKOUT_TOKEN_SECRET`.
- Admin app (Vercel) environment variables: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `CHECKOUT_TOKEN_SECRET`.
- `mobile_app/lib/core/config/checkout_config.dart` — the admin app's public URL.

### Phase 3b — Per-course commerce (replaces blanket subscriptions)

**Scope decision, taken explicitly**: pricing is now **per course only**. The blanket "Rishi Mode" subscription still exists in schema and still works, but nothing sells it — `has_course_access(user, course)` is the single gate for course content, and a subscription no longer governs it.

**New schema** (`20260731000001`, `20260731000002`, `20260731000003`):
- `courses.price_amount` (paise), `currency`, `seat_limit`, `short_description`
- `course_purchases` — one row per attempt, `status in (pending, paid, failed, refunded, revoked, duplicate)`
- `has_course_access(user, course)` — free course, or admin, or a paid non-expired purchase
- `has_media_access_via_course(user, type, id)` — lets a purchased course authorize its lessons' underlying audio/video rows in the license functions
- `coupons` + `redeem_coupon()` — percent/flat, optionally course-scoped, with an atomic conditional UPDATE so a race for the last redemption has exactly one winner
- `lesson_resources` — PDFs/images/files/links attached to a lesson. Added because handouts were originally modelled as lesson *types*, which made a PDF count as a step in the curriculum; they are attachments, so `lesson_type` was narrowed back to audio/video/text.

**Notifications**: `_shared/n8n.ts` (edge) and `admin/src/lib/n8n.ts` (Node) post a payment payload to n8n, which fans out to WhatsApp via Wati and a Google Sheets log. Course and subscription payments route to separate workflow URLs (`N8N_COURSE_PAYMENT_WEBHOOK_URL`, falling back to `N8N_PAYMENT_WEBHOOK_URL`). The importable workflow lives in `n8n/course-payment-success.json` — kept in the repo so the payload contract and the automation consuming it move together.

**Admin**: per-course price/seats, coupon management, an enrolled-students roster per course (name, email, amount paid, coupon, enrolment date, revenue total), Remove/Restore access per student, and a "duplicates to refund" badge.

### Phase 4 — LMS core (courses, modules, lessons, video playback)

Built as `20260730000003_lms_core.sql` plus the `lms` feature folder in the app and `(dashboard)/courses/` in admin. Deliberate deviations from the roadmap's sketch, each documented in the migration header: no unique index on `position` (reordering would violate it mid-swap), a single nullable `category_id` rather than a join table, and **no `course_enrollments` table** — "my courses" is derived from `lesson_progress`, since a denormalized table is a second write path that can drift from the rows it summarizes.

**The video-playback gap is closed.** `video_player` + `chewie`, fed by the existing `issue-playback-license` function. Media is hosted on **Bunny Stream** (direct browser→Bunny TUS upload from the admin, no R2 staging), with a quality selector built from the master playlist's own variant list.

### Phase 5 — Completion certificates

**Migrations**: `20260801000003_quizzes_and_certificates.sql`, then `20260801000004_certificate_templates.sql` and `20260801000005_completion_without_quizzes.sql`.

**Quizzes were built and then removed.** `20260801000003` created `quizzes`, `quiz_questions`, `quiz_options` and `quiz_attempts` alongside `certificates`, with server-side grading and the answer key withheld from clients by a column-level GRANT. Authoring questions turned out to be more work than these courses need, so the whole feature was taken out of the admin and the app: `20260801000005` redefines `course_completion_state()` to count lessons only.

The quiz **tables are deliberately still there**, empty and unreferenced. They cost nothing dormant, and dropping them is irreversible whereas re-enabling is a UI change plus restoring the quiz half of that function. Do not "tidy them up" without meaning to make that decision permanent.

**Certificates are records verified by number, not PDFs in a bucket** (a deliberate departure from §5.2 of the roadmap). A PDF is a file anyone can edit and re-share; a number that resolves against `verify_certificate()` can actually be checked by whoever is shown it. The app renders the certificate natively and a public `/verify` page (outside the admin login — a verifier has no account here by definition) resolves a number to name/course/date and nothing else: no user id, no email, no course id. Revoking sets `revoked_at` and keeps the row, because deleting would make a withdrawn credential indistinguishable from a forged number. Nothing forecloses adding a PDF export later.

**Completion is finishing every lesson.** `course_completion_state()` is the single piece of arithmetic that both the app's progress bar and `issue_certificate()` read, so what a learner is shown and what they are granted cannot disagree. A course with no lessons is never complete, so an empty draft can't hand out certificates. `issue_certificate()` is idempotent, so the course screen can call it without tracking whether it already has.

**Admin**: a Certificates page with revoke/reinstate.

**Whose name goes on it**: `issue_certificate()` originally read `profiles.display_name` and nothing else — a column that is empty for anyone who signed up with email/password and never set a name, which is most buyers. Certificates were being issued to "Student". The name was never missing, only unsaved: checkout collects it as `billing_name`, passes it to Razorpay and n8n, and discarded it. `20260801000006` keeps it on `course_purchases`, and the certificate now prefers the profile name (chosen by the person) falling back to the billing name (typed for a payment form). The webhook also fills an empty `profiles.display_name` from it, so the app stops greeting buyers by email address. Certificates issued before this are backfilled the next time the course screen calls `issue_certificate()`, which is idempotent — and only ever fills a blank, so an admin-corrected name is never overwritten. The Certificates page allows editing the printed name directly, for the pre-migration blanks and for names typed badly at checkout; the course title is deliberately not editable there, since it is a claim about what was earned.

**Admin-designed certificate artwork**: the app originally drew the certificate itself, which guarantees a consistent result but gives the admin no say in how a branded, shareable artefact looks. So `courses` gained `certificate_template_url` plus four layout columns: the admin uploads finished artwork with the name area left blank, and the only thing the system adds is the name.

Position is stored as **percentages of the image, never pixels** — the same template has to land correctly in the admin's preview pane, on a phone, and at whatever resolution the artwork was exported at, and a pixel offset would be right in exactly one of those. The admin preview uses CSS container-query units against the artwork's own width and the app uses `LayoutBuilder` against its rendered width, so the two agree by construction. A course with no template still gets the app's drawn design, so this is additive and a half-configured course degrades to something presentable.

The artwork is **not** snapshotted onto the certificate record, unlike the course title. Design is presentation — re-uploading better artwork should improve every certificate already issued. The title is a claim about what was earned and must never change retroactively. That distinction is deliberate.

**Manual award**: there is deliberately no "create certificate" form — a certificate is earned, and the Certificates page only lists what has been issued. But the enrolled-students roster on each course has an **Award** button per student, which bypasses the completion check for the cases that check cannot see (offline cohorts, migrated students, progress lost to a bug). It mints the same number format `issue_certificate()` does, so a manual award is indistinguishable to a verifier — that is the point, not an oversight: it is a real credential, not a marked-down one. Awarding someone who holds a revoked certificate reinstates it rather than minting a second.

### Live sessions + push notifications (outside the numbered rollout)

**Migration**: `20260801000007_live_sessions_and_push.sql`.

Not a roadmap phase — the roadmap's Phase 6 is scaling hardening. This was asked for directly: announce a Zoom meeting in the app, remind people an hour, 30 minutes and 5 minutes before it starts, and let them tap through to join.

**Where it lives**: the Watch tab, above the YouTube list. They are the same thing to the person using the app — free, open, played outside it — and splitting them would mean someone had to already know which tab a session lived under to find out whether one was on.

**A session is a link, a picture and a time.** `live_sessions` deliberately does not validate that `join_url` is a Zoom URL: Zoom is what's used today, but a Meet or Teams link works identically in the app and rejecting one would be a rule with nothing behind it. `duration_minutes` is a display hint — it decides when the card stops reading as "live now" — not something anything enforces, because sessions overrun and that's normal.

**All the timing logic is in one function.** `due_session_reminders()` answers exactly one question: which sessions have crossed a 60/30/5-minute mark that hasn't been sent? The edge function is a fan-out and the n8n workflow is a clock; neither knows what "due" means. The window it accepts is deliberately generous — the mark, plus anything up to ten minutes past it — so a scheduler that runs every five minutes, or misses a beat entirely, still catches the mark rather than stepping over it. Sending a 30-minute reminder at 27 minutes is fine; sending nothing is not.

**`session_reminders` is what makes polling safe.** A unique constraint on `(session_id, minutes_before)` is the guard, and the send function **claims before it sends** — the reverse of the mistake the payment webhook made, where claiming afterwards would have let two overlapping cron runs both notify everybody. If the send then fails, the claim is released so the next run retries, rather than leaving a reminder permanently marked sent when nothing was sent.

**Editing a session does not clear its reminders.** Moving a session an hour later must not re-send the "starts in an hour" people already got; a second one reads as a bug, and the reschedule itself is what needs announcing, not the countdown. Cancel and recreate if the reminders should genuinely run again.

**`push_tokens` is keyed on the token**, not on the user and not on a device id. The token is what FCM actually addresses and what it invalidates — a user key would lose someone's second device, and a device key would go stale the moment the OS reissued a token for the same install. FCM's HTTP v1 API has no multicast send, so a fan-out is N requests at a bounded concurrency of 20; every token is attempted even when earlier ones fail, because one dead handset must not stop a reminder reaching everybody else. Tokens FCM reports as permanently dead (404, or `INVALID_ARGUMENT` on the token) are deleted; transient failures (429, 503) are kept, since pruning on those would delete a live device over a momentary outage. Signing out unregisters the token, or reminders would follow the handset to whoever signs in next.

**Push is optional at boot**, for the same reason audio and downloads are. A missing `google-services.json`, a denied permission or a handset with no Play Services must all end with the app running normally and no reminders — never a crash on a screen someone was trying to reach. `PushService` swallows its own failures and reports `isAvailable = false`; the Gradle plugin is applied only when `google-services.json` is actually present, so a checkout without it still builds.

**The notification channel id `session_reminders` is written in three places** — the manifest's `default_notification_channel_id`, the channel `PushService` creates, and the `channel_id` the send function puts on the FCM payload. If any two disagree, Android quietly files the notification under a default channel and the high-importance setting is silently lost. FCM also posts nothing of its own while the app is in the foreground, which is exactly when a reminder is most likely to get someone into the call, so foreground messages are re-posted through `flutter_local_notifications`.

**Also fixed here**: the mini-player's progress bar never moved. It read `PlaybackState.position`, which only emits on play/pause/seek — the bar was drawn correctly and simply sat frozen in between. It now reads the player's continuous `positionStream`, the same fix the Now Playing screen had already needed, and shows elapsed/total in tabular figures so the text doesn't jiggle every second.

### Content notifications — new content, and a daily audio

**Migration**: `20260801000008_content_notifications.sql`.

Three reasons to open the app, three notifications: something is starting soon (live sessions, above), something new arrived, and it's morning.

**"New" means newly published, not newly created.** Courses and audios are drafted and published later, sometimes weeks later, so `created_at` was the wrong signal in both directions — a course drafted in June and published today would never be announced, and one created and published in the same minute would be announced by accident. Both tables gained `published_at`, stamped by a trigger on the transition into `published`. The trigger uses `is distinct from` rather than `<>`, because `OLD.status` is null on insert and `null <> 'published'` is null, not true — the straight-to-published insert would silently never stamp.

**The back catalogue is pre-marked as announced.** The migration seeds `notification_log` with every already-published course and audio. Without that, the first cron run after deploy would push a notification for every piece of content ever published — the single worst thing this feature could do, and irreversible. A 48-hour lookback window sits behind that as a second net: something published a month ago but somehow missing from the log is not news, and announcing it would be worse than staying quiet.

**`notification_log` is the general form of `session_reminders`** — unique on `(kind, key)`, claimed before the send, released if the send fails. Deliberately a second table rather than a merge: the two carry different keys (a session plus a minute mark, versus a content id or a date), and rewriting an applied migration to unify them would trade a small duplication for a real risk of a broken chain.

**The daily nudge is keyed on the date**, which is what makes "once a day" hold however often the cron fires, and makes a retry free. UTC deliberately — the job runs at one moment for everybody, and a local date would make "today" ambiguous at exactly the point the guard needs to be unambiguous. The track is picked least-recently-featured first, never-featured before that, ties broken at random, so the library rotates on its own: no curation list to maintain, no "featured" flag for someone to forget to move, and a newly added track surfaces within a day. An empty library does **not** claim the day — if audio is published later, that evening's run still sends.

**Two Android channels, not one**: `session_reminders` (high importance) and `content_updates` (default). Someone who wants the morning nudge muted should not lose the reminder that a session they signed up for is starting. Each id is written in three places — the manifest, `PushService`, and the sending function's payload — and if any two disagree Android quietly files the notification under a default channel and the importance is lost.

**Tapping a notification goes somewhere.** Every payload carries a `deep_link` go_router path, and `PushService` funnels all three tap sources into one stream: FCM's `onMessageOpenedApp` (backgrounded), `getInitialMessage` (cold start, parked in `pendingDeepLink` because nothing is listening that early), and the local plugin's own response callback (foreground, where FCM posts nothing itself). A new audio needed a destination that didn't exist, so `/audio/:id` was added — it resolves the id, starts playback, and replaces itself with Now Playing, so back goes where the user was rather than to a loading screen they'd have to escape twice.

### Push fan-out at scale

**Migration**: `20260801000009_push_fanout_progress.sql`.

The first version of the fan-out read the whole token list in one query and sent it in one invocation. Both halves had a ceiling, and both failed silently — the worst property a limit can have.

**The unbounded read.** PostgREST enforces a server-side row cap, so past it the token list came back truncated with no error. The function would report `sent: 1000, failed: 0`, look completely healthy, and most of the audience would hear nothing. Replaced with a **keyset walk**: tokens are read in sorted chunks and the cursor is the last token, not a row offset. That matters because dead tokens are deleted mid-walk, and an offset would skip a device every time a pruned row ahead of it shifted the rest backwards. A key cannot be invalidated by a deletion elsewhere in the list.

A short page is deliberately **not** treated as the end of the table. If the server's cap is lower than the requested chunk size, every page comes back short — which would read as "finished" after the first one and reintroduce exactly the truncation this replaced. Only an empty page ends the walk. Verified by simulation against caps of 1000, 500, 100 and 25 with heavy concurrent pruning: every surviving token receives exactly one send, and no token outside the original set is ever contacted.

**The wall clock.** A send is claimed *before* it goes out, so an invocation that timed out mid-fan-out left the notification marked sent with only part of the audience reached, and nothing would retry it. Deliveries are now resumable: the claim row carries `delivery_cursor`, `recipient_count` and `completed_at`, progress is written after every chunk, and both functions finish any open claim before looking for new work. `due_session_reminders()` and `due_content_announcements()` both exclude claimed rows, so without that resume pass an interrupted delivery would sit half-sent forever.

The rendered notification is stored on the claim as `payload`. A resume must not reconstruct the message from a session or course that may have been edited in between — the second half of an audience has to receive the same text as the first half.

**Concurrency raised from 20 to 100.** All the requests go to one host over HTTP/2, so they share connections rather than opening a socket each, and the round trip dominates. At 20, a large audience made the wall clock the binding constraint rather than a theoretical one.

Failure handling distinguishes the two cases: a claim that has never delivered anything is released so the next run retries from scratch (a failure there is the token read or the FCM credentials, both of which fail before the first send), while a claim that already has a cursor keeps it and resumes.

### Subscription lifecycle — expiry reminders

**Migration**: `20260801000010_subscription_lifecycle.sql`.

**There is no auto-renewal in this system, and that is the fact everything here follows from.** A subscription payment is a one-off that extends `profiles.access_expires_at` by the plan's interval; no Razorpay Subscriptions API, no mandate, no card on file. Every renewal is a customer deciding to buy again — so the message telling them access is about to end *is* the renewal mechanism, not a courtesy on top of one. Until this, the only warning was an in-app banner at seven days, which reaches exactly the people who were already opening the app.

**Four marks**: seven days, three days and one day before, then once after it lapses. The last one matters most and is the easiest to leave out — somebody whose access ended yesterday is the likeliest renewal there is, and nothing was telling them it had happened.

**The reminder key includes the expiry timestamp**, so renewing starts a fresh cycle automatically. The same user gets warned again before their *next* expiry with no separate reset step that could be forgotten or run twice.

**Checkout was collecting a phone number and throwing it away** — passed to Razorpay and to n8n, never stored. Exactly the omission `billing_name` had, found the same way: something needed to contact a user and had nothing to contact them with. `profiles.phone` now holds it, filled by the webhook on any successful payment and only ever into a blank, so a number the user set themselves is never overwritten.

**Push and WhatsApp are sent independently and neither blocks the other.** Somebody who never installed the app still has a phone number; somebody who never bought through checkout has devices but no number. Requiring both would have silently dropped whichever group was missing a channel. A reminder that reached one channel and not the other is still marked complete — re-sending it in full an hour later would give the people it *did* reach a duplicate, which reads worse than the people it missed getting it once.

**`sendToUser` is deliberately separate from `fanOut`.** A broadcast is unbounded and has to be resumable; one user has a handful of devices and always finishes in a single pass. Folding them together would carry cursor machinery through the case that provably never needs it.

Lifecycle events go to their own n8n webhook (`N8N_LIFECYCLE_WEBHOOK_URL`, falling back to `N8N_PAYMENT_WEBHOOK_URL`). A payment message congratulates somebody and an expiry message asks them to come back; sharing a workflow would mean branching on event type forever, with a change to renewal copy risking the receipt copy.

**Two importable workflows ship with this**: `n8n/subscription-payments.json` (the confirmation a subscription buyer never used to get — the webhook has always sent the payload with `content_type: "subscription"`, but `N8N_PAYMENT_WEBHOOK_URL` was never set, so nobody was listening) and `n8n/access-expiry-reminders.json` (the WhatsApp half of the reminders, split into separate "ending soon" and "already ended" branches because those ask for different things and read wrong forced into one template).

Both need the same three placeholders filled that the course workflow needed — `REPLACE_TENANT_ID`, `REPLACE_WITH_WATI_TOKEN`, `REPLACE_WITH_SPREADSHEET_ID` — plus the Google Sheets credential re-selected on import, and four Wati templates approved: `subscription_purchase_success`, `subscription_payment_failed`, `access_expiring`, `access_lapsed`.

### In-app guide (chat assistant)

**Migration**: `20260801000011_chat_assistant.sql`. **Function**: `chat`. **Screen**: `/chat`, entered from a row directly under Home's search bar.

**Available to everyone, free and paid, with a daily allowance** — 20 questions per person per IST day, `CHAT_DAILY_LIMIT` to change it. Putting the guide behind the paywall would have withheld it from exactly the people who most need to be told how to sit for ten minutes; leaving it uncapped would have made an LLM endpoint an open invoice. The allowance is counted from `chat_messages` itself rather than a counter table, so there is nothing to drift and no midnight reset job that can fail quietly — the window moves on its own.

**The day is an IST day.** A UTC boundary rolls over at 05:30 local, which would hand somebody a fresh allowance mid-sitting and cut another off at breakfast.

**Grounded in the real library.** `chat_catalogue()` returns every published audio and course; `chat_user_context()` returns this caller's tier, purchases and last fifteen listens. Without them, "which meditation should I start with?" gets a confident, well-written, entirely invented track name — that is the difference between a guide and a plausible liar.

**The two are separate functions on purpose, and the split is the cost model.** The catalogue is byte-identical for every caller, so it goes into the prompt ahead of the per-user block with a cache breakpoint after it, and the provider serves it from cache at a tenth of the price. Folding the user's progress into the catalogue would make every request a unique prefix and multiply the running cost of the feature by roughly ten. If anyone ever reorders those system blocks, that is what breaks — silently, and only on the invoice.

**Recommendations are tappable.** The model writes links as `[Title](app://audio/<uuid>)`; the app parses them out of the prose into chips under the bubble, matching on a strict uuid shape so a hallucinated slug can't route anywhere. Both destinations already existed — `/audio/:id` is where the daily notification lands.

**The safety boundary is not optional and was not a question.** An app like this gets asked about panic, grief, insomnia and suicide — routinely, not occasionally. The system prompt hands off clinical questions rather than improvising therapy, and carries Indian helplines (Tele-MANAS 14416, AASRA, Vandrevala, iCall) rather than the US numbers a model reaches for by default.

**Conversations are the user's alone.** RLS scopes them to `auth.uid()` with no admin policy — someone asking a meditation app about their insomnia has not agreed to it becoming staff reading material — and there is no update policy at all, so an answered question can't be edited out from under its reply. "Clear conversation" is a real delete.

**Nothing is stored until a reply exists.** Both rows are written together after the completion returns, so a failed turn costs nothing from the allowance and leaves no half-conversation to reload.

**Haiku 4.5 by default**, not Sonnet. The ceiling on answer quality here is the context, which is handed to the model; at a 20-a-day allowance across a free user base the difference between the tiers is the difference between a bill worth paying and one worth cancelling. `CHAT_MODEL` switches it without a redeploy.

**Verify JWT stays ON** — the function reads the caller's own JWT and every query below it runs under their RLS.

**The guide answers in English, Hindi or Marathi**, matching whatever the person wrote — including Roman-script Hindi and Marathi, which are answered in Roman script rather than "corrected" into Devanagari. Two things never change language: track titles, quoted exactly so the link label matches the screen it opens and so a search for it still finds it; and the helpline digits. The app's own interface is still English throughout — this is the assistant only.

Marathi is called out explicitly as not a dialect of Hindi, because the failure mode without that instruction is a Marathi question answered in Hindi on the grounds that it is close enough.

**Voice input** uses `speech_to_text`, which drives the platform's own recogniser — Android's `SpeechRecognizer`, iOS's `SFSpeechRecognizer`. Nothing is uploaded, nothing is billed per minute, and whatever languages the handset already handles come back for free, which matters for a user base that switches between English and Hindi mid-sentence.

**Dictation deliberately does not auto-send.** The transcript lands in the field and the user presses send. Recognisers mishear names and Hindi words often enough that auto-sending would spend one of the day's twenty questions on a garbled sentence nobody got to read.

Three platform requirements, all of which fail quietly or at review time rather than at build time:
- `RECORD_AUDIO` in the Android manifest. No Play Console declaration needed — unlike the media permissions, this is an ordinary runtime permission.
- A `<queries>` entry for `android.speech.RecognitionService`. Without it, Android 11+ package-visibility hides every recogniser and `initialize()` returns false on a perfectly capable handset.
- `NSMicrophoneUsageDescription` **and** `NSSpeechRecognitionUsageDescription` in `Info.plist`. The microphone string already existed for the audio framework and said the app "does not record" — that stopped being true when voice input shipped, and an understated purpose string is what App Review rejects.

### Bug-fix chronology — Phases 3b through 5

Every one of these was found by testing on a real device, not by review.

| Bug | Root cause and fix |
|---|---|
| Video upload never arrived at Bunny | R2→Bunny server-side pull is a black box that fails silently. Replaced with direct browser→Bunny TUS upload. |
| Modules invisible in the course builder despite a non-zero count | `lesson_resources(*)` was embedded in the modules select, and **one failing embed kills the entire PostgREST select**, returning null data. Split into a separate query. This trap recurs — every subsequent list query in this codebase fetches children flat and joins in code for the same reason. |
| Course stayed locked after a successful payment; n8n never fired | `handleCoursePurchase` upserted with `onConflict: "razorpay_order_id"` against a **partial** unique index. Postgres refuses a partial index as an ON CONFLICT target unless the statement repeats the predicate, which PostgREST's `on_conflict` cannot express. One error, both symptoms. Replaced with update-then-insert. **This same trap has now been hit three times in this codebase** — the third was `create-order`'s pending row, whose error was never read, so abandoned checkouts had silently never been recorded at all. |
| Payment succeeded but the app returned to a "Page not found" | `meditationapp://payment-success?...` parses with `payment-success` as the **host** and an empty path; go_router routes on the path, so it resolved to `/`. Reshaped to `meditationapp://app/payment-success`. Also proved go_router receives deep links natively via Flutter's Router API, making the `app_links` listener redundant — it was racing go_router and lost. Removed. |
| Chrome interrupted the return with an "Open Know Thyself?" prompt | Custom-scheme navigations are confirmed by Chrome. The return link is now an `intent://` URI, which Chrome resolves itself. Matched on scheme alone, with no `package=`, because the debug build installs under a different application id. |
| Course opened but stayed locked after paying | The landing screen was racing the webhook: access is granted by `razorpay-webhook`, called server-to-server, and the deep link usually wins. Invalidating a cache can't fix a value that is still correct. It now polls `has_course_access` for up to 20s before forwarding. |
| Back from a course showed a black screen | `context.go()` replaces the navigation stack, so arriving via deep link made the course the only route; popping left the navigator empty. Both back controls now fall back to `/courses`. |
| PDFs opened as a flat image with no page controls | The URL was handed to the browser, which rendered it inline. Resources are now downloaded and passed to the system "open with" chooser via `open_filex`. |
| Video playback 409'd on a video Bunny had long since finished | Bunny sends no webhook, so `bunny_status` only advanced when an admin pressed Refresh. The license now asks Bunny directly and writes the answer back, and the admin Videos page syncs unfinished rows on load. A check that cannot reach Bunny returns "unknown" and **fails open** — an unverifiable status must not be permanently fatal. |
| Video then failed with a bare ExoPlayer `Source error` | Three faults stacked. (a) `Deno.env.get(...)!` asserts nothing at runtime, so an unset `BUNNY_STREAM_PULL_ZONE` produced `https://undefined/...`. (b) The playback token omitted `token_path` from the signed message and rode in the query string; Bunny folds every `token_*` parameter into the HMAC, and a **directory token must live in the URL path** (`/bcdn_token=…`) because HLS segment URLs are relative — a query-string token is dropped at the first `.ts` request. Verified byte-for-byte against bunny.net's own signer. (c) The Stream library's **"Block direct URL file access"** overrides the pull zone's own toggle. |
| The webhook silently stopped granting anything, logging only "already processed, skipping" | The idempotency claim was inserted **before** the work it guards and never released on failure. One failed delivery poisoned that payment permanently: every Razorpay retry took the skip branch and returned 200. The claim is now released on any non-2xx. |
| A student whose access was removed could never buy the course again | Revocation originally dated `expires_at` in the past but left `status = 'paid'`, which still occupies `uq_course_purchases_paid`. Checkout refused them as already owning it, and had it not, the webhook's write would have violated the index **after** the card was charged. Withdrawal now moves the row to `status = 'revoked'`. A `duplicate` status covers the remaining race where someone genuinely pays twice — recorded, not lost, and flagged for refund. |
| n8n received nothing | Three separate causes over as many attempts, each invisible because the notifier logged nothing: the URL wasn't set on the function; then a `/webhook-test/` URL nobody was listening on; then a production URL whose **workflow was not activated**. `notifyN8n` now logs every outcome — skipped (naming the missing variable), failed (quoting n8n's own response body), and succeeded (host and path, never the query string). |
| `pubspec.yaml` was zero bytes on the release branch | The commit that bumped the build number to `+11` deleted all 90 lines of the file instead of editing the version line — no dependencies, no fonts, no version. `flutter pub get` fails outright, so the 2.0.0+11 build could never have been produced. Restored from the previous commit with the version line set. A version bump touching a hundred lines is the tell; check the diff stat, not just the diff. |
| Google Sheets logged Wati's API response instead of the payment | The Sheets node was left on **Map Automatically**, so it wrote whatever the previous node emitted. Manual mapping with `$('Normalise').item.json.*` reaches back past the Wati node to the payment data. |


---

## 8. Environment Variables & Secrets Reference

None of these are committed to the repo (correctly). Listed here so a fresh setup knows exactly what to provision.

### Supabase Edge Function secrets (`supabase secrets set ...` or Dashboard → Edge Functions → Secrets)
| Secret | Used by | Purpose |
|---|---|---|
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID`, `R2_BUCKET` | `issue-audio-license`, `issue-playback-license`, `issue-upload-url` | Cloudflare R2 signing (pre-existing, not part of this session's work) |
| `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | `razorpay-webhook` | Used to fetch the Razorpay order directly (Basic Auth to `GET /v1/orders/{id}`) — the authoritative source for which user/plan a payment belongs to. Same credential pair as the admin app's, just also needed here now. |
| `RAZORPAY_WEBHOOK_SECRET` | `razorpay-webhook` | Verifies the webhook signature Razorpay sends |
| `CHECKOUT_TOKEN_SECRET` | `mint-checkout-token` | Signs the short-lived checkout token |
| `BUNNY_STREAM_PULL_ZONE` | `issue-playback-license` | e.g. `vz-abc123.b-cdn.net`. **Required** — the function now throws with the variable named if it's missing, rather than building `https://undefined/...` |
| `BUNNY_STREAM_TOKEN_KEY` | `issue-playback-license` | The pull zone's **Token Authentication key** (Pull Zone → Security), NOT the Stream API key. Leave UNSET unless token auth is on — see the note below |
| `BUNNY_STREAM_API_KEY`, `BUNNY_STREAM_LIBRARY_ID` | `issue-playback-license` | Reads live encode status, since Bunny sends no webhook. Optional: absent, the status check returns "unknown" and fails open |
| `N8N_COURSE_PAYMENT_WEBHOOK_URL` | `razorpay-webhook` | Course-payment automation. Falls back to `N8N_PAYMENT_WEBHOOK_URL` |
| `N8N_PAYMENT_WEBHOOK_URL` | `razorpay-webhook` | Subscription-payment automation. **Not set** — so subscription buyers currently get no WhatsApp confirmation and no Sheets row, while course buyers do. Duplicate the course workflow in n8n and point this at it |
| `N8N_LIFECYCLE_WEBHOOK_URL` | `send-content-notifications` | Access-expiry reminders (7/3/1 days before, once after). Falls back to `N8N_PAYMENT_WEBHOOK_URL`. Absent, push still goes out and only the WhatsApp side is missing — logged, not silent |
| `ANTHROPIC_API_KEY` | `chat` | The in-app guide. Absent, the function returns 503 with a written apology and logs the variable name — the chat screen is reachable but every question fails, so this is the one to check first if the guide "does nothing" |
| `CHAT_MODEL` | `chat` | Optional. Defaults to `claude-haiku-4-5-20251001`. Set to a Sonnet id if the answers ever read as thin — the cost difference is roughly 3× |
| `CHAT_DAILY_LIMIT` | `chat` | Optional, defaults to 20 questions per person per IST day. Raising it raises the worst-case bill in direct proportion |
| `FCM_SERVICE_ACCOUNT` | `send-session-reminders`, `send-content-notifications` | The **entire** service-account JSON from Firebase console → Project settings → Service accounts → Generate new private key. Not a path, not a key id. Absent, the function returns a config error naming it and releases its reminder claim so nothing is silently marked sent |

> **Bunny token authentication is deliberately OFF.** A directory token cannot survive the jump from an HLS master playlist to its renditions on a native player — ExoPlayer and AVPlayer cannot re-attach a token to segment requests at runtime, and Bunny's own workaround is a JavaScript hook that only exists in web players. Setting `BUNNY_STREAM_TOKEN_KEY` again will break playback. Access is gated by `issue-playback-license` (purchase, device lock, access window), not by the CDN.

### Admin app (Vercel) environment variables
| Variable | Purpose |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Pre-existing Supabase client setup |
| `R2_*` | Pre-existing, cover image uploads |
| `RAZORPAY_KEY_ID` | Public-safe, used client-side in the Checkout.js embed |
| `RAZORPAY_KEY_SECRET` | Used server-side to create Razorpay orders |
| `CHECKOUT_TOKEN_SECRET` | Verifies the token minted by `mint-checkout-token` — **must be the exact same value** as the Supabase secret of the same name |
| `BUNNY_STREAM_API_KEY`, `BUNNY_STREAM_LIBRARY_ID` | Direct browser→Bunny video upload, and encode-status polling on the Videos page |
| `N8N_COURSE_PAYMENT_WEBHOOK_URL` | Only fires for a 100%-off coupon, where `create-order` grants access itself and so must notify n8n itself. Easy to forget until a free enrolment silently sends nothing |

### Mobile app config files (Dart constants, not env vars — Flutter has no runtime env var mechanism for this)
| File | What to set |
|---|---|
| `lib/core/config/google_auth_config.dart` | Google OAuth Web Client ID |
| `lib/core/config/checkout_config.dart` | The admin app's public URL |
| `ios/Runner/Info.plist` | `GIDClientID` + `CFBundleURLSchemes` (Google OAuth iOS client) |
| `android/app/google-services.json` | Firebase project `anurag-rishi-1c479`. **In the repo** — it is client config, restricted by package name and shipped inside every APK anyway, so keeping it out would only mean a build that silently has no push. The Gradle plugin is still applied conditionally, so a checkout without the file builds fine. **Only `com.knowthyself.app` is registered so far — add a second Android app for `com.knowthyself.app.debug`** or push won't work in debug builds, the same suffix trap that broke Google Sign-In earlier |

---

## 9. Repository Structure

```
Rishi_app2/
├── mobile_app/                    Flutter app (Dart) — what users install on their phone
│   ├── lib/
│   │   ├── app/                   App-wide plumbing: go_router setup, theme, the persistent
│   │   │                          bottom-nav shell widget
│   │   ├── core/                  Cross-feature utilities that don't belong to one feature:
│   │   │   ├── config/            Plain Dart constants for things that would be env vars in
│   │   │   │                      a backend app (Google OAuth client ID, checkout base URL) —
│   │   │   │                      Flutter has no runtime env var mechanism, so these are
│   │   │   │                      literal source files with a placeholder to replace
│   │   │   ├── device/            Device fingerprinting (for the one-device-per-account lock)
│   │   │   ├── errors/            AuthFailure — the app's typed error model, shared by every
│   │   │   │                      auth-adjacent feature so the UI can switch on error *type*
│   │   │   │                      instead of parsing message strings
│   │   │   └── network/           Supabase client provider
│   │   └── features/              One folder per user-facing feature. Each follows the same
│   │       │                      internal layering (see "Feature layering" note below):
│   │       ├── auth/              Login, signup, forgot password, Google Sign-In, device
│   │       │                      registration
│   │       ├── access/            Resolves what tier a user is in (admin/retreat/free) and
│   │       │                      whether they should see the "N days left" banner or a
│   │       │                      next-event popup. Also owns the checkout-link-minting
│   │       │                      datasource (added in Phase 3) even though the actual
│   │       │                      "locked item" UI lives in home/
│   │       ├── home/              Home screen, browse/search screen, and the shared
│   │       │                      premium-lock dialog widget used by both
│   │       ├── audio/             Streaming, background playback, the Now Playing screen
│   │       ├── downloads/         Encrypted offline downloads, offline player
│   │       └── profile/           Profile screen, subscription display, device list
│   ├── android/                   Android build config, keystore setup, AndroidManifest.xml
│   │                              (permissions, deep links, package-visibility <queries>)
│   └── ios/                       iOS build config, Info.plist (permissions, OAuth URL
│                                  schemes)
│
├── admin/                         Next.js admin dashboard — internal tool for staff, PLUS
│   │                              (since Phase 3) the public checkout page for end users
│   └── src/
│       ├── app/
│       │   ├── (dashboard)/       Admin-only pages (users, audios, videos, categories,
│       │   │                      devices, settings). Every page here is gated by
│       │   │                      requireAdmin() via the shared (dashboard)/layout.tsx.
│       │   ├── actions/           Server Actions — the only place that's allowed to write
│       │   │                      to the database from the admin UI. Convention: every
│       │   │                      action calls requireAdmin() first, uses the service-role
│       │   │                      client, returns {ok: true} | {ok: false, error: string}.
│       │   ├── api/checkout/      Route Handler for creating a Razorpay order. Public
│       │   │                      (no admin login) — protected by the checkout token
│       │   │                      instead, since callers are anonymous mobile app users.
│       │   ├── checkout/          The public checkout page itself (/checkout/[planId]).
│       │   │                      Also public, also token-protected, also NOT part of the
│       │   │                      admin dashboard despite living in this app.
│       │   └── login/             Admin staff login page
│       ├── components/            Shared UI (shadcn-based: Button, Card, Dialog, Table, ...)
│       │                          plus feature-specific components (content upload dialog,
│       │                          user actions menu, etc.)
│       ├── lib/                   Same role as mobile's core/: env.ts (centralized env var
│       │                          access with clear errors), supabase/ (client factories —
│       │                          one for the logged-in user's session, one service-role
│       │                          "admin" client that bypasses RLS), access.ts (tier
│       │                          resolution, mirrors the mobile/SQL logic), razorpay.ts +
│       │                          checkout-token.ts (Phase 3)
│       └── middleware.ts          Runs on every request. Redirects anyone unauthenticated
│                                  to /login — EXCEPT /checkout and /api/checkout, which are
│                                  deliberately public.
│
└── supabase/
    ├── migrations/                All SQL schema migrations, in chronological order by
    │                              filename timestamp. This is the single source of truth
    │                              for the database schema — never edit a table by hand in
    │                              the dashboard without also writing a migration for it.
    └── functions/                 Deno edge functions — server-side code that runs outside
        │                          the Next.js/Flutter apps, callable via HTTPS. Used for
        │                          anything that needs a secret the client can't hold
        │                          (signing R2 URLs, verifying webhook signatures) or that
        │                          must run with elevated database privileges.
        ├── _shared/                Code shared between multiple functions (NOT auto-bundled
        │                          when a function is deployed by pasting into the Supabase
        │                          Dashboard's single-file editor — only the CLI's
        │                          `supabase functions deploy` command picks these up
        │                          correctly. If deploying via Dashboard, inline the shared
        │                          code into the one file instead.)
        │   ├── cors.ts             CORS headers + a jsonResponse() helper, used by every fn
        │   ├── r2.ts                Cloudflare R2 presigned-URL signing
        │   ├── razorpay.ts          Webhook signature verification (Phase 3)
        │   └── checkout_token.ts    Mints the signed user+plan token (Phase 3)
        ├── issue-audio-license/    Signs a playback URL for one audio track
        ├── issue-playback-license/ Signs playback URLs for a video (multiple qualities)
        ├── issue-upload-url/       Admin-only: signs an upload URL for new content
        ├── mint-checkout-token/    Phase 3: mobile app calls this to start a purchase
        └── razorpay-webhook/       Phase 3: Razorpay calls this directly (not the app) —
                                   the only place a purchase actually grants access

    (_shared also now holds bunny.ts — playback URL signing, encode-status
     polling and manifest verification — and n8n.ts, the payment
     notification fan-out.)

n8n/                              Importable n8n workflow JSON. Kept in the repo
                                  rather than only in n8n's own database, so the
                                  payload contract in _shared/n8n.ts and the
                                  automation consuming it move together — a
                                  renamed field shows up here as a diff instead
                                  of as a silently empty WhatsApp variable.
```

### Feature layering (mobile app)

Every folder under `mobile_app/lib/features/<name>/` follows the same four-layer split. When adding something to an existing feature, put new code in the matching layer rather than improvising a new structure:

- **`domain/`** — plain Dart classes with no dependency on Supabase or Flutter widgets: entities (e.g. `AudioSummary`, `AccessState`), repository *interfaces* (abstract contracts), and use cases (a single public method wrapping one repository call — mostly there for testability, not because the logic is complex).
- **`data/`** — the real implementation: a `*RemoteDataSource` class that actually talks to Supabase (queries, RPC calls, edge function invocations), and a `*RepositoryImpl` that implements the domain interface by calling the datasource and translating errors into the app's typed `AuthFailure`/exception model.
- **`application/`** — Riverpod wiring: `*_providers.dart` builds the dependency graph (datasource → repository → usecase), and for features with real state machines (auth), a `*Controller` (a Riverpod `Notifier`) holding a sealed `*State` type the UI watches.
- **`presentation/`** — everything Flutter-widget-shaped: `screens/` (one file per route) and `widgets/` (small reusable pieces used by more than one screen in the same feature, or that are complex enough to deserve their own file).

The admin app doesn't use this layering — it's a much thinner app, and Next.js Server Actions already give a similar separation (`actions/` = data layer, page components = presentation, no separate domain/application layers because there's no complex client-side state to manage).

---

## 10. Known Issues / Next Steps

As of the end of the push-notification session, in priority order:

1. **This branch (`claude/repo-structure-overview-vt36iu`) still has not been merged to `main`.** Nothing in Section 7 is live for real users until that happens. `checkout_config.dart` now points at the stable production alias (`https://rishi-app2.vercel.app`) rather than a per-deployment preview URL, so that particular breakage is resolved either way.

2. **Phase 5 (certificates) has still not been tested end-to-end on a device.** Both apps build clean and migrations `20260801000003` through `20260801000006` are applied. Upload certificate artwork on a course, position the name, complete every lesson on a phone, and claim the certificate. This is the largest untested surface left.

   **Push, live sessions and the WhatsApp flows ARE tested** — token registration, the daily audio nudge, notification tap-through, a 60-minute session reminder, and both new n8n webhook workflows (subscription payments and access expiry) have each been confirmed end to end.

   Still untested: the 30- and 5-minute session marks, new-course and new-audio announcements, expiry reminders driven by the real cron rather than a direct webhook POST, and any resumed (`complete: false`) delivery — that last one needs an audience larger than a single invocation, so it cannot be exercised at current scale. **A real live-mode Razorpay payment end to end is the largest remaining gap**: the n8n side is proven by direct POST, but nothing has yet confirmed that Razorpay actually reaches the webhook with live keys.

3. **Firebase and Google Sign-In share one project — keep it that way.** The app briefly carried a `google-services.json` for a *different* Google Cloud project than the one `googleWebClientId` points at, and Google Sign-In failed with `DEVELOPER_ERROR` until they were consolidated onto `rishi-503917` / project number `395908400723`. Anything that touches either — a new SHA-1, a new OAuth client, a rotated service-account key — must be done in that project and nowhere else.

   Two SHA-1s are registered: release `E7:D2:10:CC:FC:8C:18:B4:D3:80:CA:0C:69:E9:D6:92:92:41:DF:FC` and debug `79:C4:CB:7E:09:2E:5D:33:11:FF:AD:F2:D7:AD:63:D0:C6:82:D5:CC`. **`com.knowthyself.app.debug` is not yet registered as a Firebase app**, so debug builds get no push and no Google Sign-In. And if the app is ever distributed through Play with App Signing, Play re-signs it with a third key whose SHA-1 must also be registered — otherwise sign-in works in local release builds and fails for everyone who installs from the store.

4. **Operational landmines that have each cost a testing round.** Written down because they are not discoverable from the code:
   - **"Verify JWT" resets to ON after every `supabase functions deploy`**, and must be OFF for `razorpay-webhook`. Razorpay's POST is rejected with 401 before any code runs. The durable fix is a `[functions.razorpay-webhook] verify_jwt = false` block in the local `supabase/config.toml` (untracked — it holds the project ref).
   - **The Supabase CLI's migration history is empty** because migrations were applied by hand in the SQL editor. `supabase db push` therefore offers to replay all of them, which would fail partway. Either run `supabase migration repair --status applied <version>` for each existing migration once, or keep applying by hand.
   - **Deploy after pulling.** Several rounds were lost to a deployed function predating the fix being tested.
   - **An n8n workflow that is saved, correct and tested still does nothing until it is activated**, and gives no indication it isn't running. This has now cost rounds on both the payments workflow and the reminders workflow. The check is n8n's Executions list: regular runs returning `due: 0` are the proof it is alive.
   - **Verify JWT must stay ON for `send-session-reminders` and `send-content-notifications`** — the opposite of `razorpay-webhook`, and easy to get backwards out of habit. Both check the `service_role` claim themselves.
   - **Times are pinned to IST in two places that must agree**: `formatDateTime` in the admin, and the session form's `istInputToIso`/`isoToIstInput`. The admin pages are server components and the server runs in UTC, so an unpinned format renders five and a half hours off what the client-side form accepted. The n8n daily schedule pins the same zone in `settings.timezone`.

5. **Refunds owed.** At least one duplicate payment (`pay_TKA6LFBfAzXBiu`) bought nothing and needs refunding in Razorpay. The course page shows a "duplicates to refund" badge once `20260801000002` is applied.

6. **Legacy revoked enrolments block repurchase.** Anyone revoked before the `status = 'revoked'` mechanism landed still has a lapsed-but-`paid` row occupying the unique index. One-time cleanup:
   ```sql
   update public.course_purchases set status = 'revoked', updated_at = now()
   where status = 'paid' and expires_at is not null and expires_at <= now();
   ```

7. **Not started, from the original roadmap**: Stripe (non-India), the admin Billing page (payment history + refund button), the account-deletion flow, and per-item purchases of individual audios/videos (`entitlements` remains ready and unused — courses use `course_purchases` instead).

8. **Phases 6 and 7 (scaling, load testing) have not been started** — see `README.md` and Section 11 below, which sets out what actually binds first.

9. **Certificates download as a PNG, not a PDF.** The app renders the on-screen certificate to a ~2000px image via RepaintBoundary and hands it to the system share sheet, which is how it gets saved as well as shared. A PDF would need a layout engine and a font pipeline to reproduce what is already being drawn correctly; if one is ever wanted, the record and its number already exist, so it is a rendering job rather than a data-model change.

---

## 11. Capacity — what this can carry today

Assumes Supabase **Pro**, Cloudflare R2, and Bunny Stream, with the usage shape of a meditation app: people open it once or twice a day for ten to twenty minutes. Verify the Supabase quotas against their current pricing page before betting on them — plan limits change.

**Headline: roughly 50,000 registered users / 10,000 daily actives before anything has to be touched.**

### What breaks, in order

| # | Limit | Breaks at | How you'd find out |
|---|---|---|---|
| 1 | Postgres compute (Pro defaults to a Micro instance) | ~10,000 daily actives | Slow queries, then timeouts |
| 2 | Edge function invocations (2M/month included) | ~35,000–65,000 users | A billed overage, ~$2 per extra million |
| 3 | Auth MAU (100,000 included) | 100,000 monthly actives | Billed per MAU |
| 4 | Push fan-out | ~500,000 devices per invocation, and past that it simply takes more cron runs | Nothing breaks; deliveries report `complete: false` and resume |
| 5 | Bunny video egress | No ceiling — cost only | Your invoice |

**Compute is the one you will actually feel**, and it is a slider in the Supabase dashboard, not an architecture change: Micro → Small → Medium, minutes of downtime, $15–60/month. Opening the app fires roughly eight queries (home, categories, courses, continue-listening, live sessions, access, profile), all indexed.

**Edge functions are the metered resource.** Every audio play calls `issue-audio-license`, every video calls `issue-playback-license`. At 30 plays per user per month, 2M invocations covers about 65,000 users; at 60 plays, about 33,000. The notification crons contribute roughly 11,500 invocations a month combined — negligible.

**Audio costs nothing to serve.** R2 has no egress fees, which is the single best property of this stack.

**Video is where the money goes.** A thousand people watching a 30-minute HD lesson is on the order of 1–2 TB through Bunny. That is a pricing question to model before a launch push, and it is unrelated to how much load the system can carry.

**Paid vs free makes no meaningful difference to load.** A paid user hits `has_course_access` and the license functions slightly more often; that is one indexed lookup. Razorpay absorbs payment volume, and the webhook is a single write per purchase. The device lock (one account, one device) caps concurrent streams per account at one, which helps.

**Storage will not bind.** 100,000 users with full progress history sits well under the 8 GB included.

### What was already fixed to get here

The push fan-out originally broke at about **1,000 devices, silently** — an unbounded token read that PostgREST truncated with no error, so the function reported success while most of the audience heard nothing. See "Push fan-out at scale" in Section 7. That was the only limit standing between this app and every other number on this page.

---

*Last updated: 2 August 2026, after live sessions, push notifications, and the fan-out scaling work. Phases 3b, 4 and 5 landed in one extended session before that; see the bug-fix chronology at the end of Section 7 for what broke along the way and why.*
