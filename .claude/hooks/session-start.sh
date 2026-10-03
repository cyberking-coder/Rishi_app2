#!/bin/bash
#
# Installs the Flutter SDK and fetches mobile_app dependencies so
# `flutter analyze` and `flutter test` work in Claude Code on the web.
#
# The cloud container ships no Flutter SDK and is wiped between sessions,
# so this runs at session start. The container state is cached after the
# first successful run, so later sessions skip the ~1GB download and only
# re-export PATH and run a fast pub get.
set -euo pipefail

# Web only — a local machine already has its own Flutter.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR=/opt/flutter
# Pinned for reproducibility (stable channel, Dart 3.13.5). Bump when you
# want a newer SDK. Must stay >= 3.27 — the app uses Color.withValues.
FLUTTER_VERSION=3.47.6

# Make flutter available for this session (cheap; runs every start).
echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Install once. Idempotent: skipped when a working SDK is already cached.
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  curl -fsSL -o /tmp/flutter.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm -rf "$FLUTTER_DIR"
  tar -xf /tmp/flutter.tar.xz -C /opt
  rm -f /tmp/flutter.tar.xz
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
git config --global --add safe.directory "$FLUTTER_DIR" || true
flutter --disable-analytics >/dev/null 2>&1 || true

# Pre-fetch mobile dependencies so analyze/test are ready immediately.
(cd "$CLAUDE_PROJECT_DIR/mobile_app" && flutter pub get)
