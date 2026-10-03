#!/bin/bash
#
# Runs the device-level E2E catalog sweep against a staging backend.
# Reads config from environment variables so no secret is ever hard-coded.
#
# Required (or they fall back to the app's baked-in AppConfig / anonymous):
#   E2E_SUPABASE_URL, E2E_SUPABASE_ANON_KEY, E2E_EMAIL, E2E_PASSWORD
# Optional:
#   E2E_CHECK_LICENSES (default true)
#   E2E_CHECK_PLAYBACK (default false)
#   E2E_PLAYBACK_SAMPLE (default 0 = all)
#
# Usage:
#   export E2E_SUPABASE_URL=https://xxx.supabase.co
#   export E2E_SUPABASE_ANON_KEY=...
#   export E2E_EMAIL=tester@example.com E2E_PASSWORD='...'
#   scripts/run_e2e.sh
set -euo pipefail

cd "$(dirname "$0")/../mobile_app"

if ! flutter devices 2>/dev/null | grep -qiE "emulator|device|simulator"; then
  echo "No device/emulator detected. Start one (flutter emulators --launch <id>) first." >&2
  exit 1
fi

args=()
[ -n "${E2E_SUPABASE_URL:-}" ]      && args+=("--dart-define=E2E_SUPABASE_URL=$E2E_SUPABASE_URL")
[ -n "${E2E_SUPABASE_ANON_KEY:-}" ] && args+=("--dart-define=E2E_SUPABASE_ANON_KEY=$E2E_SUPABASE_ANON_KEY")
[ -n "${E2E_EMAIL:-}" ]             && args+=("--dart-define=E2E_EMAIL=$E2E_EMAIL")
[ -n "${E2E_PASSWORD:-}" ]          && args+=("--dart-define=E2E_PASSWORD=$E2E_PASSWORD")
args+=("--dart-define=E2E_CHECK_LICENSES=${E2E_CHECK_LICENSES:-true}")
args+=("--dart-define=E2E_CHECK_PLAYBACK=${E2E_CHECK_PLAYBACK:-false}")
args+=("--dart-define=E2E_PLAYBACK_SAMPLE=${E2E_PLAYBACK_SAMPLE:-0}")

echo "Running catalog sweep on-device..."
exec flutter test integration_test/e2e_content_sweep_test.dart "${args[@]}"
