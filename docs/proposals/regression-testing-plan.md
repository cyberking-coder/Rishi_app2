# Automated Regression Testing — Implementation Plan

Status: **Proposal / not yet implemented**
Source: `Rishi_App_Automated_Regression_Testing_PRD.pdf`
Scope of this document: a plan only. No production code is changed by writing it.

---

## 0. Where the repo stands today (baseline)

Verified against the current tree so the plan is grounded, not aspirational:

| Area | Today | Gap |
|------|-------|-----|
| Flutter tests | No `mobile_app/test/`, no `mobile_app/integration_test/`, no `*_test.dart` | Everything |
| Flutter dev deps | `flutter_test`, `flutter_lints ^4`, `flutter_launcher_icons` only | No mocking/fake lib, no `integration_test` entry |
| Admin (Next.js/TS) | `lint` + `typecheck` scripts exist; no test runner | No unit test runner (e.g. Vitest) |
| Supabase | Deno edge functions under `supabase/functions/*`; `_shared/`; no tests | No Deno test files |
| CI | **No `.github/` at all.** Mobile builds run on Codemagic (`codemagic.yaml`) | No GitHub Actions pipeline |
| Static analysis | `flutter analyze` works via `analysis_options.yaml` (flutter_lints) | Not run in CI |

Architecture is feature-first (`lib/features/<feature>/{domain,data,application,presentation}`) with Riverpod + go_router. That layering is what makes most of the PRD's targets unit-testable without a device.

---

## 1. Guiding principles (from the PRD)

1. **Bug → permanent test.** Reproduce → write failing test → fix → test passes → keep the test forever.
2. **Coverage of critical behavior beats test count.** The ~88 figure is a guide, not a target.
3. **Pyramid, not ice-cream cone.** Lots of fast unit tests, fewer widget tests, a small set of device integration tests. Do not start by automating the whole UI.
4. **P0 failures block production-bound merges.** Everything else is advisory until it is stable.

---

## 2. Test taxonomy and where each layer lives

```
mobile_app/
  test/                     # unit + widget (fast, no device, runs in CI)
    auth/
    router/
    courses/
    subscriptions/
    downloads/
    playback/
    profile/
    common/                 # shared mocks, fakes, fixtures, helpers
  integration_test/         # full-journey, device/emulator only
    auth_flow_test.dart
    course_flow_test.dart
    playback_flow_test.dart
    account_flow_test.dart

admin/
  src/**/__tests__/ or *.test.ts   # pure logic: token mint/verify, coupon math, parsing

supabase/
  functions/<fn>/*_test.ts          # Deno tests for signature verify, idempotency, access grant
```

Rationale for the split: unit + widget + Deno + TS tests are deterministic and hermetic, so they are the **PR gate**. Integration tests need an emulator and a seeded backend, so they run on a **separate, slower job** and are not required to merge day one.

---

## 3. Tooling decisions (proposed, minimal additions)

Only dev-dependencies and config — no production code touched.

**Flutter** (`mobile_app/pubspec.yaml` dev_dependencies):
- `mocktail` — mocking without codegen (no build_runner step in CI). Preferred over `mockito` for this repo because there is currently no codegen pipeline.
- `integration_test` (sdk: flutter) — for Phase 9.
- Keep `flutter_test`, `flutter_lints`.

**Admin**:
- `vitest` + `@vitest/coverage-v8` as devDependencies; add `"test": "vitest run"` script. Chosen over Jest because the project is ESM/Next 14 and Vitest needs near-zero config.

**Supabase**:
- No new dependency — use the built-in `deno test`. Add a `supabase/functions/deno.jsonc` task if one is not present.

**Seams the tests need (design constraint, not a code change now).**
Most target classes already take their dependencies via constructor (e.g. `HomeRemoteDataSource(this._client)`, `AudioRepositoryImpl(AudioRemoteDataSource(...))`, `DownloadRepositoryImpl(storage:, metadataStore:, resolver:, proxy:)`). Those are directly fakeable. Where a class reaches for a global (e.g. `Supabase.instance.client`, `path_provider`), the first test PR for that module will introduce a thin injection seam **in that module only** — that is the "change what's required" the PRD allows, done per-phase, never a repo-wide refactor.

---

## 4. Phased delivery

Each phase is a self-contained PR. Order follows the PRD. Targets are the PRD's.

### Phase 1 — Infrastructure (foundation)
- Add dev deps above; create `mobile_app/test/` and `mobile_app/integration_test/` with a `common/` holding reusable fakes (`FakeSupabaseClient`, `FakeGoRouter`, fixture builders) and helpers.
- Add `.github/workflows/regression-tests.yml` running, on push + PR:
  - `flutter pub get` → `flutter analyze` → `flutter test` (mobile)
  - `npm ci` → `npm run lint` → `npm run typecheck` → `npm run test` (admin)
  - `deno test` (supabase functions)
- **Done when:** every push/PR runs the pipeline, even with a near-empty suite.

### Phase 2 — Authentication & Router (~8–12 tests) — **P0/P1**
Protect the exact regressions this app already hit (see `PROJECT_LOG.md` §18 offline-jumps-to-Home, and the A1/A7 router fixes):
- Successful / failed login; logout clears the durable login flag (`login_flag_store.dart`).
- Login persistence & session restoration; expired-token and **offline-session** behavior.
- **Auth refresh must not recreate the router / reset navigation** (the A1 fix — GoRouter instance stays stable; `isLoggedIn` reads flag OR session).
- Authed vs unauthed route guards.
- **Missing/invalid `Lesson` route `extra` must not crash** (the A7 redirect to `/courses`).

### Phase 3 — Payments, Subscriptions & Coupons (~15–20 tests) — **P0**
Highest commercial risk. Split across the three codebases:
- Admin: `mint-checkout-token` / `create-order` — valid, invalid, expired, forged tokens; **abandoned checkout must not consume a coupon** (the A2 fix: redemption moved to payment confirmation).
- Supabase `razorpay-webhook`: valid signature grants access; **invalid signature grants nothing**; **duplicate webhook is idempotent**; failed payment grants nothing; coupon redeemed exactly once on confirmation.
- Coupon logic: valid / expired / invalid / exhausted (`redeem_coupon`).
- Subscription activation, expiry, renewal (`has_active_access` / `resolve_user_tier`).

### Phase 4 — Course & Access Control (~8–12 tests) — **P1**
`has_course_access` truth table: free course; paid denied before purchase; allowed after `course_purchases.status='paid'`; duplicate purchase; revoked access (`revoked` status); repurchase; **cross-user access denied** (RLS). Also the new fix: course-lesson audios excluded from the audio browse lists.

### Phase 5 — Downloads & Device Security (~10–15 tests) — **P0 (security)**
From `download_repository_impl.dart` + downloads migrations:
- Create / fail / interrupt / cancel; **delete-while-downloading** (the A5/A6 zombie-task race); duplicate downloads; license generation & expiry.
- Device authorization; **User A cannot read User B's download/license**; **User A cannot revoke User B's device** (the hardening migration revoking `revoke_downloads_for_device` from anon/authenticated).
- **Ownership fields cannot be rewritten by clients** (revoked `update` grants on `downloads`).

### Phase 6 — Audio & Video Playback (~8–12 tests) — **P1**
- Stream start / pause-resume / seek; signed-URL and **expired-URL** handling (the 6h TTL fix in `issue-audio-license`); network interruption.
- **Offline/downloaded playback must not reset navigation** (ties to Phase 2).
- Authorized video playback; unauthorized/expired denied (`issue-playback-license`).

### Phase 7 — Account Management (~5–8 tests) — **P0 (destructive)**
`delete-account` function + local cleanup: server-confirmed deletion → local wipe; server failure handled safely; logout cleanup; device cleanup; **login-flag cleanup**; network failure during deletion.

### Phase 8 — Backend Response & Error Handling (~8–10 tests) — **P1**
Malformed backend responses must not crash Flutter: empty objects, null token/value, unexpected fields/types → controlled `AuthFailure`/typed errors instead of `TypeError`/`CastError`. Cover checkout, chat, audio/video authorization, download/license parsers.

### Phase 9 — Critical E2E (~5–8 tests) — integration job
1. Launch → Login → Home → Logout
2. Login → Courses → Purchased course → Lesson → Playback
3. Subscription loaded → Premium content → Access granted
4. Download → Lose network → Restart → Offline playback
5. Login → Settings → Delete account → Login screen

### Phase 10 — CI enforcement (release gate)
- Static analysis first; unit/widget/backend on every PR; integration on a separate job.
- Branch protection: required checks = Phase 1 pipeline's P0/P1 jobs. P0 failing blocks merge to the production-bound branch.
- Failure output names the affected module (one job per codebase + per-phase test folders).

---

## 5. Priority → release rule

| Priority | Scope | Rule |
|----------|-------|------|
| **P0** | Payments, auth, authorization, subscription entitlement, account deletion, download security | Must block release |
| **P1** | Routing, courses, playback, offline behavior, API parsing | Normally block merge |
| **P2** | Non-critical UI, minor interactions | May be non-blocking |

Initial suite target ≈ **88** tests (Auth/Router 10, Payment/Coupons 18, Subscriptions 8, Courses 10, Downloads/Devices 12, Playback 10, Account 6, API/Error 8, Integration 6). Count is a guide, not the goal.

---

## 6. CI shape (proposed `.github/workflows/regression-tests.yml`)

Three parallel jobs on `push` + `pull_request`, plus an opt-in integration job:

- **mobile-static-and-unit**: `subosito/flutter-action` → `flutter pub get` → `flutter analyze` → `flutter test --coverage`.
- **admin**: Node setup → `npm ci` → `npm run lint` → `npm run typecheck` → `npm run test`.
- **supabase**: `denoland/setup-deno` → `deno test supabase/functions`.
- **mobile-integration** (separate, not required to merge initially): Android emulator → `flutter test integration_test`.

Required-for-merge = the three fast jobs. Integration promoted to required once green and stable.

---

## 7. Definition of Done (from the PRD)

- [ ] Flutter + backend tests + static analysis run automatically on push/PR.
- [ ] Critical auth and offline-session scenarios covered.
- [ ] Payment, webhook, coupon, subscription entitlement covered.
- [ ] Course authorization and download/device security covered.
- [ ] Account deletion and important malformed-API responses covered.
- [ ] Critical E2E journeys automated.
- [ ] GitHub clearly reports failures by module.
- [ ] P0 failures block production-bound merges.
- [ ] Every newly discovered production bug yields a permanent regression test.

---

## 8. First-PR checklist (Phase 1 only — the next actionable step)

1. Add `mocktail` + `integration_test` to `mobile_app/pubspec.yaml` dev_dependencies.
2. Create `mobile_app/test/common/` with first fakes + fixtures and **one** smoke test (`expect(true, isTrue)`) so CI has something to run.
3. Add `vitest` to `admin` devDependencies + `"test"` script.
4. Add `.github/workflows/regression-tests.yml` with the three fast jobs.
5. Seed each `test/<folder>/` with a `.gitkeep` so the structure lands.
6. No production `lib/`, `src/`, or `functions/` logic is modified in this PR.
