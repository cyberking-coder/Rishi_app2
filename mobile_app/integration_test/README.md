# Device-level E2E harness

These tests run the **real app code against a real backend on a real
device/emulator** — the layer the unit suite (`test/`) cannot cover. They are
kept out of the fast PR gate (they need a device + a staging backend + a test
account) and are meant to run on demand and on a schedule.

## What runs

### `e2e_content_sweep_test.dart` — the catalog sweep
Walks **every** published item and drives it through the production pipeline:

| Group | Checks |
|-------|--------|
| Every audio | parses via `AudioTrack.fromMap`; has a `ready` rendition in `content_assets`; `issue-audio-license` returns a URL; *(optional)* `just_audio` actually loads the stream |
| Every course + lesson | course parses; each lesson resolves; audio/video lessons point at a real media row (no dangling reference); text lessons are non-empty; referenced audios are licensable |
| Every live session | parses via `LiveSession.fromMap` |
| Every event / pop-up | parses via `AppPopup.fromMap`; iOS content policy reported |

One bad item never aborts the run — all failures are collected and printed as a
single report, and the test fails listing them.

### `e2e_user_journey_test.dart` — the critical journey, as real taps
Boots the actual app (`main()`) and drives the full flow on-screen:

> launch → **login** → home shell → **Courses** → open a course → open a
> lesson → **playback appears** (audio lessons open Now Playing) → Profile →
> Settings → **logout** → back to login.

It uses stable widget keys from `lib/core/testing/e2e_keys.dart` (so it does
not rely on visible text, which changes with the education-framing flag). The
journey degrades gracefully — if the account has no courses/lessons it still
verifies login, navigation and logout and logs what it skipped — and uses a
`pumpUntil` helper instead of `pumpAndSettle` (the player's position bar ticks
forever, so `pumpAndSettle` would hang).

Run it with a test account:

```bash
flutter test integration_test/e2e_user_journey_test.dart \
  --dart-define=E2E_EMAIL=tester@example.com \
  --dart-define=E2E_PASSWORD='<password>'
```

Without `E2E_EMAIL`/`E2E_PASSWORD` the test **skips** (it cannot log in).

> ⚠️ The journey boots the real `main()`, which initialises Supabase from the
> app's baked-in `AppConfig` — i.e. it hits **whatever backend the build
> targets**. Build/point at **staging** before running the journey so it does
> not log in against production. (The content-sweep test, by contrast, takes
> its backend from `--dart-define` and so can target staging without a special
> build.)

### `e2e_offline_download_test.dart` — offline download → offline playback
login → Home → play an audio → **tap Download** → wait for it to finish →
Downloads tab → **play the downloaded item** → the encrypted **offline
player** starts. End-to-end proof of enqueue → encrypted download → manifest →
decrypt-on-the-fly playback (the area that had the "downloaded audio won't
play" bugs). Needs an account that can download the first Home audio (free or
owned). Degrades gracefully: if nothing is downloadable or the download does
not finish within the window it records a skip, not a false failure — the firm
assertion is that offline playback works *when a download completes*.

### `e2e_streaming_audio_test.dart` — stream + mini-player
login → Home → tap an audio → Now Playing → play/pause → back → the
persistent **mini-player** shows and its control works. Covers the most-used
streaming path (where the "audio gets stuck" auto-recovery fix lives).

### `e2e_helpers.dart`
Shared helpers (`bootAndLogin`, `pumpUntil`, `audioCardFinder`) used by the
journey tests. Not a test itself.

### `smoke_test.dart`
Confirms the `integration_test` binding runs on the device (sanity check).

## Widget keys
The journey relies on keys centralised in `lib/core/testing/e2e_keys.dart`
(login fields/button, nav tabs, per-id course cards and lesson tiles, the
Settings row and Logout tile, and the play/pause control). They add no
behaviour; keep them in sync if those widgets are restructured.

## Prerequisites

1. A **device or emulator** (Android emulator or iOS simulator, or a physical
   device with `flutter devices` showing it).
2. A **staging Supabase** project (do **not** point playback/license load at
   production — it mints real signed URLs and counts against egress).
3. A **test account** that account has an **active device row**. Licensing and
   playback go through the one-device lock, so either:
   - sign in through the app once on this device/emulator (registers the
     device), **or**
   - seed a `devices` row (`user_id`, `is_active = true`) in staging.
   Without an active device the sweep still validates catalog integrity and
   clearly logs that license/playback checks were skipped.

## Running

```bash
flutter test integration_test/e2e_content_sweep_test.dart \
  --dart-define=E2E_SUPABASE_URL=https://<staging>.supabase.co \
  --dart-define=E2E_SUPABASE_ANON_KEY=<anon key> \
  --dart-define=E2E_EMAIL=tester@example.com \
  --dart-define=E2E_PASSWORD='<password>' \
  --dart-define=E2E_CHECK_LICENSES=true \
  --dart-define=E2E_CHECK_PLAYBACK=true \
  --dart-define=E2E_PLAYBACK_SAMPLE=10
```

Or use the helper: `../scripts/run_e2e.sh` (reads the same values from env vars).

### Knobs (`--dart-define`)
| Key | Default | Meaning |
|-----|---------|---------|
| `E2E_SUPABASE_URL` | app's `AppConfig` | backend to sweep |
| `E2E_SUPABASE_ANON_KEY` | app's `AppConfig` | anon key |
| `E2E_EMAIL` / `E2E_PASSWORD` | _(none)_ | test account; omit to sweep anonymously (RLS hides gated content) |
| `E2E_CHECK_LICENSES` | `true` | call `issue-audio-license` for every audio |
| `E2E_CHECK_PLAYBACK` | `false` | actually load each stream with `just_audio` (slower; proves on-device decode) |
| `E2E_PLAYBACK_SAMPLE` | `0` (all) | cap how many streams are load-tested |

## Credentials & safety
- Pass secrets as `--dart-define` / env vars — **never** commit them.
- Point at **staging**. A full sweep with `E2E_CHECK_PLAYBACK=true` downloads
  the opening of every track.

## CI
This does not run on the PR gate. The scheduled workflow
`.github/workflows/e2e-nightly.yml` runs the sweep on an Android emulator
against staging (secrets provided via repo/environment secrets). Promote it to
a required check only once it is stable and fast enough for your cadence.
