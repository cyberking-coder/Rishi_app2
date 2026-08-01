# Know Thyself — LMS Integration & Scale-Up Plan

**Status: Phases 0-5 are built (branch `claude/repo-structure-overview-vt36iu`, still not
merged to `main`). Phases 0-4 are tested end-to-end on a real device; Phase 5 is written
and building but not yet exercised, and its migration is not yet applied. See
`PROJECT_LOG.md` Section 7 for exactly what shipped and what broke along the way, and
Section 10 for what's still unresolved/unstarted.** This
file remains the single source of truth for the *plan* — how we take the existing
meditation/audio app and turn it into a full Learning Management System (LMS) with free
and premium tiers, self-service signup, Razorpay + Stripe payments, and infrastructure
that holds up at ~10 lakh (1,000,000) users — **without breaking anything that already works.**

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
- Free users can **unlock premium content/courses themselves** by tapping
  "Get Access Now," which takes them to an external web checkout (Razorpay
  for India, Stripe for the rest of the world, auto-selected by region) —
  never an in-app purchase flow, to stay outside Apple/Google's in-app
  billing requirements — *or* an admin can still grant premium access
  manually (today's flow, unchanged).
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
| **Premium User** | Admin manually sets `access_expires_at` in the future | **Three** paths now: admin-grant (unchanged, blanket access), self-service **per-course purchase** via the external web checkout (see §6 — grants that one course only), or a self-service **blanket subscription** if we offer one (sets `access_expires_at`, same as admin-grant) |
| **Free User** | Doesn't exist yet — all users are admin-created | New: self-signup via the app, `access_expires_at = null` **and no active premium purchase/entitlement** → free tier, sees only free-marked content |

**No new database column is required to represent this, for either access
model.** Blanket premium reuses `access_expires_at` exactly as today. Per-course
purchases reuse the **existing `entitlements` table** — already fully designed
(`user_id`, `content_id`, `source`, `expires_at`) but currently unpopulated by
any code (flagged as dead schema in the original audit). A course purchase
inserts one row: `source = 'purchase'`, `content_id = <course id>` — course
access is then "has an active entitlement for this course OR an active
`access_expires_at` window OR is admin," which is a small extension to the
gating check, not a new mechanism. `is_premium` already exists on
`videos`/`audios`/`content_assets` to mark which content requires *some* form
of access; the new `courses` table gets the same flag for consistency.

**Content gating rule (already partially enforced today via `has_active_access`
RPC used in `issue-audio-license`):** any content row with `is_premium = true`
requires an active access window **or** a matching entitlement; `is_premium =
false` is open to any authenticated free user. Course-level lessons inherit
this from their parent course, so gating logic isn't duplicated per-lesson.

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

## 6. Payments — Razorpay + Stripe, entirely outside the app

**No in-app purchase SDK, no in-app checkout UI, no card form inside the
Flutter app — deliberately.** Payment happens on a web page, not inside the
app binary, specifically so we never trigger Apple's In-App Purchase
requirement or Google Play Billing for digital content. The app never says
"buy," "premium," or "subscribe" next to a checkout button — the only CTA is
**"Get Access Now."**

### 6.1 Flow
1. User taps **"Get Access Now"** on a locked course/content item in the app.
2. The app opens the device's **external browser** (`url_launcher` in
   `externalApplication` mode — not an in-app WebView, which matters for the
   same store-policy reasons as not using an SDK) to a web checkout page:
   `https://<web-portal-domain>/checkout/<course-id>?token=<signed-token>`.
   The signed token identifies the user + course without requiring them to
   log in again on the web.
3. That web page is a small new surface — either a new lightweight route on
   the existing Next.js admin app's public side, or a new minimal Next.js app
   reusing the same Supabase project and the same `_shared` R2/CORS patterns
   already established. It detects region and shows **Razorpay Checkout**
   (India/INR) or **Stripe Checkout** (everywhere else) — auto-routed exactly
   as planned, just relocated from "inside the app" to "on the web."
4. User pays on the provider's own hosted checkout — **card details never
   touch our servers**, keeping PCI scope minimal, same guarantee as before.
5. Provider sends a webhook → `razorpay-webhook` / `stripe-webhook` edge
   functions verify the signature, write a `payments` row, and grant access:
   - **Course purchase** → insert an `entitlements` row (`source: 'purchase'`,
     `content_id: <course id>`) — unlocks that course only.
   - **Blanket subscription purchase** (if offered) → upserts `subscriptions`
     and sets `profiles.access_expires_at`, exactly as the admin's manual
     grant does today.
   Either way, `has_active_access`/entitlement-check logic needs **no
   changes** to recognize paid access alongside admin-granted access.
6. On success, a background job (see §7) sends:
   - a **confirmation email** (Resend/Postmark), and
   - a **WhatsApp message** (new — see §7 for provider options),
   both containing the receipt and a note that the course is now unlocked.
7. **Unlocking in-app**: the app re-checks entitlement/access state whenever
   it resumes from background — which is exactly what happens when the
   external browser is closed and the user returns to the app after paying.
   This reuses the same on-mount refetch pattern `accessStateProvider`
   already uses today (no new polling system); we extend the resume trigger
   from "screen mount" to "app lifecycle resume" so the unlock feels
   immediate without the user needing to force-quit or re-navigate.

### 6.2 Why this shape, explicitly
Apple and Google both require in-app digital purchases to go through their
own IAP/Billing systems (with their revenue cut) *if the purchase happens
inside the app*. Routing the entire payment experience — button tap through
confirmation — to an external website is the standard way apps avoid that
requirement for this kind of content. This is a deliberate, real trade-off
worth having explicitly on record (expanded in §8) rather than silently
assumed.

### 6.3 Idempotency & reliability
Webhook events get queued (see §7) rather than processed synchronously, with
a `webhook_events` table (new, small) recording provider event IDs already
seen, so a retried webhook from Razorpay/Stripe during a network hiccup can
never double-grant access, double-send the WhatsApp/email confirmation, or
double-charge.

### 6.4 Admin visibility
New admin "Billing" page: payment history, active subscriptions/entitlements,
refund button (calls the provider's refund API, updates `payments.status`,
and revokes the matching `entitlements`/`access_expires_at` grant), and
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
| WhatsApp purchase confirmation | **WhatsApp Business Platform** via a BSP such as **Twilio**, **Gupshup**, or **MSG91** (final choice deferred — see §10) | Needed for the post-purchase confirmation message in §6.1; all three integrate cleanly with a webhook-driven background job |
| Web checkout hosting (the external payment page in §6) | Same **Vercel/Next.js** setup already used for the admin dashboard | One more route on infrastructure we already operate, not a new deployment target |
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
- **App Store / Play Store risk of the external-checkout model (§6), flagged
  directly rather than assumed away**: routing payment entirely to an
  external website is the standard way to avoid Apple's In-App Purchase cut
  and Google Play Billing for digital content, and is explicitly what you've
  asked for. It carries real review risk on iOS in particular — Apple's
  guidelines have historically restricted linking out to external purchase
  flows for digital content except under specific exceptions ("reader" apps,
  or the newer External Purchase Link entitlement available in some regions
  including the US). This app already has a documented history of App Store
  review friction (the existing hardcoded review-account device-lock
  exemption from the original audit exists *because of* past review
  pressure). Recommendation: budget time in Phase 3 to review current Apple
  guidelines for the specific entitlement/exception that applies, and treat
  "will Apple approve this" as an open risk to validate early — ideally via
  a TestFlight submission — rather than late, so a rejection doesn't block
  the whole payments phase. Android/Google Play is comparatively more
  permissive for this pattern but not risk-free either.
- The existing hardcoded review-account device-lock exemption and the
  FLAG_SECURE removal (both flagged in the original audit) are **out of scope
  for this plan** — separate cleanup, not blocking LMS work, can be revisited
  independently.

---

## 9. Phased rollout

Each phase ships independently and leaves the app fully working. Detailed
file-by-file plans are written and approved before coding starts on each one.

| Phase | Scope | Depends on | Status |
|---|---|---|---|
| **0** | Land the Free/Retreat(Premium)/Admin role-resolution work already planned in the prior task (no DB change, pure derivation layer) | — | ✅ Done |
| **1** | Self-service signup (mobile signup screen, `handle_new_user` default tweak, email verification flow) | Phase 0 | ✅ Done (email/password + Google Sign-In) |
| **2** | Content gating pass — confirm `is_premium` is consistently enforced across audio/video for the new free-signup population (it already is via `has_active_access`, this phase is verification + admin UI to mark content free/premium per item if not already exposed) | Phase 1 | ✅ Done |
| **3** | Payments: external web checkout portal, `payments`/`subscriptions`/`entitlements` wiring, Razorpay + Stripe, webhooks, background job queue, email + WhatsApp confirmation, admin Billing page, account-deletion flow | Phase 1 | 🟡 Mostly done. 3a: Razorpay checkout + webhook. 3b: **per-course** purchases, coupons, seat limits, enrolment roster, access revocation, and WhatsApp + Sheets confirmation via n8n/Wati. Still open: Stripe, admin Billing page with refunds, account deletion. |
| **4** | LMS core: courses/modules/lessons schema, admin course builder, mobile course catalog + lesson player (including finally building video playback UI), lesson progress | Phase 2 | ✅ Done — incl. Bunny Stream video hosting and a quality selector |
| **5** | Quizzes + certificates | Phase 4 | ✅ Built, not yet tested. Migration `20260801000003` not yet applied. |
| **6** | Scaling hardening: connection pooling, read replicas, Redis caching, CDN tuning, monitoring/error tracking wired up | Can start in parallel with Phase 3 onward, tuned continuously | Not started |
| **7** | Load testing at simulated 10-lakh-user scale, fix bottlenecks found, go-live checklist | After Phase 5 and 6 | Not started |

**Also unresolved**: this work lives on git branch `claude/repo-structure-overview-vt36iu`, not yet merged to `main` — see `PROJECT_LOG.md` §7 and §10 for the full detail on everything above.

**Two design decisions departed from this roadmap deliberately**, both recorded in `PROJECT_LOG.md` §7:
per-course purchases use a dedicated `course_purchases` table rather than the `entitlements` table §3
proposed (entitlements remains unused and ready for per-*item* audio/video purchases), and certificates
are verifiable records rather than PDFs in a bucket (§5.2) — a number that resolves against
`verify_certificate()` can be checked by whoever is shown it, which a PDF cannot.

---

## 10. Open questions before Phase 0 detailed planning starts

These don't block writing this roadmap, but need an answer before the
relevant phase's file-level plan is written:

1. ~~**Pricing**~~ — **Answered: per-course, one-time.** The blanket subscription
   still exists in schema but nothing sells it; `has_course_access` is the gate.
2. ~~**Course content authoring**~~ — **Answered: both.** A lesson references an
   existing `audios`/`videos` row, and the builder's "upload new" path creates
   that row first via the normal content pipeline. A lesson never owns media.
3. ~~**Certificate design**~~ — **Answered: rendered natively + publicly
   verifiable by number**, not a PDF. See `PROJECT_LOG.md` §7, Phase 5.
4. **Video transcoding vendor** (Cloudflare Stream vs Mux) — deferred to
   Phase 4 per §7, but worth flagging now so it's not a last-minute decision.
5. ~~**WhatsApp Business Platform provider**~~ — **Answered: Wati**, driven from
   n8n rather than from our own code, so message copy and routing change
   without a deploy.
6. ~~**Blanket subscription vs per-course-only pricing**~~ — **Answered:
   per-course only** for now.
7. ~~**Web checkout portal hosting**~~ — **Answered: a public route on the existing
   admin app** (`/checkout`), exempted from its login middleware. `/verify` now
   sits alongside it on the same basis.

---

*This is a living planning document. As of Phase 5 it describes mostly-completed
work — see `PROJECT_LOG.md` for the record of what was actually built, what was
tested, and the bug-fix chronology, which is where the non-obvious traps in this
codebase are written down.*
