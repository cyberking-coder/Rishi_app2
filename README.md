# Know Thyself — LMS Integration & Scale-Up Plan

**Status: planning document only. No code has been written yet.** This file is the
single source of truth for how we take the existing meditation/audio app and turn
it into a full Learning Management System (LMS) with free and premium tiers,
self-service signup, Razorpay + Stripe payments, and infrastructure that holds up
at ~10 lakh (1,000,000) users — **without breaking anything that already works.**

Every phase below gets its own detailed file-by-file implementation plan (files
changed, why, testing steps) submitted for approval *before* any code is written,
exactly as we've been doing. This document is the roadmap those phase-plans will
be drawn from.

---

## 0. Guiding principles (non-negotiable across every phase)

1. **Extend, never rewrite.** The existing Flutter app, Next.js admin dashboard,
   Supabase schema, and edge-function patterns are the foundation. New features
   are built *inside* that architecture, not next to it.
2. **Reuse before creating.** Before any new table, API, widget, or service is
   proposed, we check whether an existing one already does the job. (This plan
   already found several — see §3.)
3. **Existing users are never disrupted.** Every phase must leave current login,
   playback, downloads, and admin workflows working exactly as they do today.
4. **Ship in small, independently-safe phases.** Each phase is deployable on its
   own and leaves the app in a working state — no long-lived half-finished branch.
5. **Reversibility.** Payment and infra integrations are built behind feature
   flags / config so any one piece can be disabled without a redeploy if it
   misbehaves.

---

## 1. What "done" looks like

- A user can **sign themselves up** for a free account (email + password via
  Supabase Auth, same mechanism already used for admin-created accounts today).
- Some content (audio, video, and new LMS courses) is marked **free**; some is
  marked **premium**.
- Free users can **upgrade to premium themselves** by paying — Razorpay for
  India, Stripe for the rest of the world, auto-selected by region — *or* an
  admin can still grant premium access manually (today's flow, unchanged).
- The app gains a proper **LMS**: courses made of modules and lessons (video,
  audio, or text), quizzes with scoring, per-lesson progress tracking, and
  completion certificates.
- The whole system is architected to **not fall over at 1,000,000 users** —
  connection pooling, caching, CDN, read replicas, job queues, and monitoring
  are added incrementally, reusing the current Supabase + Cloudflare R2 stack
  rather than a risky wholesale migration.

---

## 2. Current state (what we're building on top of)

This matters because almost everything below is an *extension*, not new ground:

| Layer | Today | Relevant to this plan because |
|---|---|---|
| Auth | Supabase Auth, but **100% admin-provisioned** — no signup screen exists in the Flutter app at all | We add self-signup; admin-creation flow is preserved as-is |
| Roles | `profiles.role` (admin/content_manager/support/user) + `access_expires_at` (access window) | This is *already* a free/premium model in disguise — see §4, no new role column needed |
| Content | `videos`, `audios`, `categories`, `content_assets` tables; Cloudflare R2 storage; edge functions sign short-lived playback URLs | Course lessons reuse `content_assets` + the same signing pattern, not a new storage system |
| Payments schema | `subscriptions`, `subscription_plans`, `payments` tables **already exist, fully designed, but currently unused by any code** | This is the single biggest reuse win — payments plug into schema that's already there |
| Admin dashboard | Next.js 14, Server Actions, `requireAdmin()` gate, service-role Supabase client | New admin screens (course builder, payments, coupons) follow the exact same pattern |
| Mobile app | Flutter, Riverpod, go_router, feature-first folders, repository pattern per feature | New features (`lms`, `payments`, `signup`) become new features in the same shape |
| Edge functions | Deno, `issue-audio-license` / `issue-playback-license` / `issue-upload-url`, shared `_shared/r2.ts` + `_shared/cors.ts` helpers | Payment webhooks and LMS content licensing become new edge functions using the same helpers |

---

## 3. User & access model — Free / Premium / Admin

We are **reusing the exact role model already scoped in the prior architecture
task** (Free User / Retreat User / Admin) rather than inventing a fourth concept.
"Retreat User" and "Premium User" are the same thing — a user with an active
`access_expires_at` window. We're just widening *how* that window gets set:

| Role | How it's granted today | How it's granted after this plan |
|---|---|---|
| **Admin** | `profiles.role = 'admin'` (or `content_manager`/`support`), created manually in Supabase | Unchanged |
| **Premium User** | Admin manually sets `access_expires_at` in the future | **Both** admin-grant (unchanged) **and** self-service purchase via Razorpay/Stripe, which sets the same column via a webhook |
| **Free User** | Doesn't exist yet — all users are admin-created | New: self-signup via the app, `access_expires_at = null` **and no active premium purchase** → free tier, sees only free-marked content |

**No new database column is required to represent this.** `access_expires_at`
already means exactly "premium until this date, or forever if null." What's new
is *how many ways* that field can be set, and a `is_premium` flag already exists
on `videos`/`audios`/`content_assets` to mark which content requires it — for
LMS courses we add the same flag on the new `courses` table for consistency.

**Content gating rule (already partially enforced today via `has_active_access`
RPC used in `issue-audio-license`):** any content row with `is_premium = true`
requires an active access window; `is_premium = false` is open to any
authenticated free user. Course-level lessons inherit this from their parent
course, so gating logic isn't duplicated per-lesson.

---

## 4. Self-service signup

- **Mechanism**: Supabase Auth `signUp()` — the exact same underlying primitive
  `signInWithPassword` already uses, so no new auth provider is introduced.
- **New mobile screen**: a Sign Up screen (currently doesn't exist — today's
  Login screen has no "create account" path). Reuses the existing
  `AuthTextField` widget, `AuthRepository`/`AuthRemoteDataSource` pattern, and
  `go_router` auth-redirect logic already in place.
- **Verification**: email confirmation via Supabase's built-in flow (already
  configured — `createUser` in the admin dashboard currently sets
  `email_confirm: true` to skip it for admin-created accounts; self-signup users
  go through the normal confirm-by-link flow instead).
- **New account defaults**: `role = 'user'`, `access_expires_at = null` and
  `subscription_tier = 'free'` — i.e., they land as a Free User automatically,
  no admin action required. The existing `handle_new_user` trigger already
  auto-creates the `profiles` row on signup; it needs a small extension so the
  defaults it inserts match "free tier," not the current implicit blank state.
- **Device lock**: the existing one-device-per-account lock (`register_device`
  RPC) applies identically to free and premium users — no change needed there.
- **Abuse control**: per your call, email verification only (matches how the
  app already behaves) — no CAPTCHA or phone OTP gate on the signup form
  itself. We compensate at the infrastructure layer instead (see §6 — rate
  limiting and bot protection sit in front of the API, not the form), which is
  cheaper to operate and doesn't add signup friction, and can be tightened
  later without a mobile app release if abuse patterns emerge.

---

## 5. LMS design

### 5.1 Scope (per your call: full LMS)
Courses → Modules → Lessons, quizzes with scoring, per-lesson progress
tracking, and completion certificates.

### 5.2 New database tables (additive only — nothing existing is altered)

| Table | Purpose | Reuses |
|---|---|---|
| `courses` | Title, description, cover image, `is_premium`, status (draft/published/archived), category | Same status/RLS pattern as `videos`/`audios` |
| `course_modules` | Ordered groups of lessons within a course | Mirrors `playlist_tracks`' ordering pattern |
| `lessons` | Ordered content unit — video, audio, or text/markdown; points at a `content_assets` row for its media (or a `videos`/`audios` row, whichever fits the content) | **Reuses `content_assets` + the existing R2 signing edge functions** — no new storage/licensing system |
| `lesson_progress` | Per-user, per-lesson completion + position, mirrors `watch_history`'s shape | Same pattern as `watch_history`/`upsert_watch_progress` RPC |
| `quizzes` | One quiz attached to a lesson or a course | — |
| `quiz_questions` / `quiz_options` | Question bank, multiple choice to start | — |
| `quiz_attempts` | Per-user attempt + score + answers | — |
| `certificates` | Issued on course completion — PDF stored in the existing `covers`-style public bucket or R2, record kept here | Reuses the storage pattern already used for cover images |
| `course_enrollments` | Tracks which courses a user has started (derived from `lesson_progress` existing, but kept as a fast-lookup table for "my courses") | — |

All new tables get RLS following the exact pattern every existing table
already uses: `is_admin()` for admin write access, own-row-or-admin for
user-facing reads, `SECURITY DEFINER` RPCs for anything that needs atomic
cross-table writes (e.g., completing a course and issuing a certificate in one
transaction, mirroring how `register_device` is already an atomic RPC).

### 5.3 Mobile app additions
New `lib/features/lms/` feature folder, same domain/data/application/presentation
layering as every existing feature (`audio`, `downloads`, `profile`, etc.):
course catalog screen, course detail/module list, lesson player (branches to
the *existing* `NowPlayingScreen`/audio pipeline for audio lessons, and a new
lightweight video player for video lessons — see §5.4), quiz screen, progress
indicators reusing the existing `progressFraction`-style patterns already in
`ContinueListeningItem`, and a certificate/achievements screen.

### 5.4 The video-playback gap
The earlier audit found the mobile app has **zero video playback UI** despite
the backend already supporting it. LMS video lessons make this unavoidable —
this plan is where a `video_player` integration finally gets built, reusing
the existing `issue-playback-license` edge function (already built, currently
unused) rather than writing new licensing logic.

### 5.5 Admin dashboard additions
New `(dashboard)/courses/` section: course/module/lesson builder (reuses the
existing `upload-content-dialog` R2-upload pattern for lesson media), quiz
builder, enrollment/completion stats, certificate reissue. Follows the exact
Server Action + `requireAdmin()` + service-role-client pattern every existing
admin page already uses.

---

## 6. Payments — Razorpay + Stripe

### 6.1 Routing
Auto-detect by region (billing country / locale) at checkout: Razorpay for
India (INR), Stripe for everyone else. Both gateways write into the **same
existing `payments` and `subscriptions` tables** — the schema already has
`payment_provider`/`provider_subscription_id`/`provider_payment_id` columns
sitting unused for exactly this purpose.

### 6.2 Flow
1. Free user taps "Go Premium" in the app → mobile app calls a new edge
   function `create-checkout-session` → returns a Razorpay order or Stripe
   Checkout session depending on detected region.
2. User completes payment in the provider's own hosted checkout (Razorpay
   Checkout / Stripe Checkout) — **card details never touch our servers**,
   keeping PCI scope minimal.
3. Provider sends a webhook → new edge functions `razorpay-webhook` and
   `stripe-webhook` verify the signature, write a `payments` row, upsert the
   `subscriptions` row, and set `profiles.access_expires_at` — reusing the
   exact column the admin's manual "grant access" button already writes to,
   so premium-gating logic (`has_active_access`) needs **zero changes** to
   support paid access alongside admin-granted access.
4. Renewal/cancellation/refund webhooks update the same rows going forward.

### 6.3 Idempotency & reliability
Webhooks are the one place at this scale where "every possible paid tool" pays
for itself immediately: webhook events get queued (see §7) rather than
processed synchronously, with a `webhook_events` table (new, small) recording
provider event IDs already seen, so a retried webhook from Razorpay/Stripe
during a network hiccup can never double-grant or double-charge access.

### 6.4 Admin visibility
New admin "Billing" page: payment history, active subscriptions, refund
button (calls the provider's refund API + updates `payments.status`), and
manual coupon/pricing management if we want promotional pricing later.

---

## 7. Scaling to ~10 lakh users — the paid tool stack

Per your call, we **scale the current Supabase + Cloudflare R2 stack** rather
than migrate to a different cloud. Every tool below is added incrementally —
this is not a day-one requirement list, it's a menu we pull from as real usage
data tells us where the bottleneck actually is (see phased rollout in §9).

| Concern | Tool | Why this one |
|---|---|---|
| DB connection exhaustion at scale | **Supavisor** (Supabase's built-in pooler, paid-tier plans include higher connection limits) | Already part of the platform we're on — no new vendor |
| Read-heavy queries (course catalog, dashboards) | **Supabase read replicas** (paid add-on) | Avoids splitting the DB layer into a separate system |
| Hot-path caching (session validation, popular course/audio metadata, rate-limit counters) | **Upstash Redis** (serverless, pay-per-request — fits our edge-function-based backend better than a self-managed Redis box) | No server to manage, integrates cleanly with Deno edge functions |
| Media delivery at scale (course video/audio, cover images) | **Cloudflare CDN in front of R2** (Cloudflare is already our storage vendor) | Keeps everything in one vendor relationship, R2 egress to Cloudflare's own CDN is free |
| Background jobs (webhook processing, certificate PDF generation, email sends, analytics rollups) | **Inngest** or **Trigger.dev** (managed queue/worker platform with a generous free tier, paid at scale) | Edge functions are request/response — durable background jobs need a real queue, and this plugs into Deno/TypeScript cleanly |
| Bot / abuse protection at the edge (compensates for the "no CAPTCHA on signup" choice) | **Cloudflare WAF + rate limiting** (already sitting in front of R2, extend to API routes) | One vendor, one dashboard, no new integration surface |
| Error tracking | **Sentry** (Flutter + Next.js + Deno SDKs all exist) | Covers all three runtimes with one tool |
| Uptime/log monitoring | **Better Stack** (or Supabase's own log drains, evaluated in Phase 5) | Cheap, fast to wire up |
| Load testing before go-live | **k6** (Grafana Cloud k6, paid tier for larger runs) | Industry standard, scriptable, integrates with CI |
| Transactional email (verification, receipts, certificates) | **Resend** or **Postmark** | Both have first-class Supabase/Next.js integrations |
| Video transcoding for course lessons (multiple qualities, matching the `content_assets` "quality ladder" design that already exists in schema but is unpopulated) | **Cloudflare Stream** or **Mux** (evaluated against each other in Phase 4 — decision deferred until we scope lesson-video volume) | Finally populates the multi-quality `content_assets` design instead of the current single-rendition-only reality |

**Why this order matters**: none of this is deployed on day one. Connection
pooling and caching are cheap and go in early (Phase 5). CDN and WAF are
close to free and go in early too. Background jobs go in with payments
(Phase 3), since webhook reliability needs them immediately. Load testing
(Phase 6) happens *before* any marketing push, not after something breaks.

---

## 8. Security & compliance notes

- Card data never touches our infrastructure — both Razorpay Checkout and
  Stripe Checkout are hosted, keeping us out of PCI-DSS scope directly.
- All webhook handlers verify provider signatures before writing anything
  (standard Razorpay HMAC / Stripe signature verification) — no webhook
  payload is trusted blind.
- New tables get RLS from day one, following the existing project convention
  — no table ships without it, matching every table audited earlier.
- The account-deletion gap flagged in the original architecture audit (a
  static compliance page exists but no real delete flow) gets addressed as
  part of this work, since a real payments/subscriptions system raises the
  compliance stakes — a proper "delete my account" edge function is in scope
  for Phase 3.
- The existing hardcoded review-account device-lock exemption and the
  FLAG_SECURE removal (both flagged in the original audit) are **out of scope
  for this plan** — separate cleanup, not blocking LMS work, can be revisited
  independently.

---

## 9. Phased rollout

Each phase ships independently and leaves the app fully working. Detailed
file-by-file plans are written and approved before coding starts on each one.

| Phase | Scope | Depends on |
|---|---|---|
| **0** | Land the Free/Retreat(Premium)/Admin role-resolution work already planned in the prior task (no DB change, pure derivation layer) | — |
| **1** | Self-service signup (mobile signup screen, `handle_new_user` default tweak, email verification flow) | Phase 0 |
| **2** | Content gating pass — confirm `is_premium` is consistently enforced across audio/video for the new free-signup population (it already is via `has_active_access`, this phase is verification + admin UI to mark content free/premium per item if not already exposed) | Phase 1 |
| **3** | Payments: `payments`/`subscriptions` wiring, Razorpay + Stripe checkout, webhooks, background job queue for webhook processing, admin Billing page, account-deletion flow | Phase 1 |
| **4** | LMS core: courses/modules/lessons schema, admin course builder, mobile course catalog + lesson player (including finally building video playback UI), lesson progress | Phase 2 |
| **5** | Quizzes + certificates | Phase 4 |
| **6** | Scaling hardening: connection pooling, read replicas, Redis caching, CDN tuning, monitoring/error tracking wired up | Can start in parallel with Phase 3 onward, tuned continuously |
| **7** | Load testing at simulated 10-lakh-user scale, fix bottlenecks found, go-live checklist | After Phase 5 and 6 |

---

## 10. Open questions before Phase 0 detailed planning starts

These don't block writing this roadmap, but need an answer before the
relevant phase's file-level plan is written:

1. **Pricing**: one-time premium purchase, or recurring subscription
   (monthly/yearly)? `subscription_plans` schema already supports recurring —
   confirming this avoids rework in Phase 3.
2. **Course content authoring**: will lesson video/audio be freshly produced,
   or do existing `audios`/`videos` rows get "promoted" into course lessons?
   Affects whether `lessons` references existing content rows or always gets
   its own upload.
3. **Certificate design**: any branding/template requirements, or is a simple
   auto-generated PDF (name, course, date) sufficient for Phase 5?
4. **Video transcoding vendor** (Cloudflare Stream vs Mux) — deferred to
   Phase 4 per §7, but worth flagging now so it's not a last-minute decision.

---

*This is a living planning document — it will be updated as each phase's
detailed implementation plan is approved and merged. Nothing in this file
changes existing app behavior; it describes work not yet started.*
