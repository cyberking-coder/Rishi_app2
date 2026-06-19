# Security Hardening — Anurag _Rishi app

A practical summary of what protects the audio content and the app, and how
to build/release securely. No client-side scheme is unbreakable (a user can
always re-record their own speaker — the "analog hole"), but these layers
stop casual copying and beginner-level attacks.

## Layers already in place

| Layer | What it does |
|---|---|
| **Private R2 bucket** | Audio has no public URL. The only way to fetch bytes is a presigned URL minted server-side. |
| **Short-lived presigned URLs** | Playback/download URLs expire in ~10 min, so a leaked URL is useless soon after. |
| **AES-256-CTR encrypted downloads** | Offline files on the phone are encrypted; the key is in the OS secure storage. Plaintext is never written to disk. |
| **Loopback decrypting proxy** | Offline audio is decrypted only in memory and streamed over `127.0.0.1` behind a per-session random token. |
| **Supabase Auth + RLS** | Every request is authenticated; Row-Level Security stops users reading rows they don't own. |
| **Single-device lock** | An account works on one device at a time (`register_device`), curbing credential sharing. |
| **Per-play license checks** | The `issue-audio-license` edge function re-checks device + entitlement on every play. |
| **Scoped cleartext policy** | Plain HTTP is permitted ONLY for `127.0.0.1` (the proxy); all other traffic must be HTTPS. |

## Layers added in this pass

| Layer | What it does |
|---|---|
| **FLAG_SECURE** | Blocks screenshots & screen recording app-wide, and hides content in the recent-apps switcher. (`MainActivity.kt`) |
| **R8 obfuscation + shrinking** | Release APK's Kotlin/Java code is obfuscated and dead code/resources stripped, so decompiling it yields little. (`build.gradle` + `proguard-rules.pro`) |

## Build a hardened release

Always build the release with **Dart obfuscation** on (renames Dart symbols
so the compiled `libapp.so` is hard to read):

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-symbols
```

For an App Bundle (Play Store):

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-symbols
```

> Keep the `build/debug-symbols` folder — you need it to de-obfuscate crash
> stack traces later.

If a release build ever fails after enabling R8, the first suspect is a
missing keep rule — add the offending class to `proguard-rules.pro` (or
temporarily set `minifyEnabled false` to unblock, then fix the rule).

## Optional, higher-effort layers (not yet added)

- **Certificate pinning** — pin Supabase/R2 TLS certs so a user can't use a
  proxy (Charles/Fiddler) with their own root cert to read presigned URLs.
  Powerful, but breaks when certs rotate; needs maintenance.
- **Root / jailbreak detection** — refuse to run (or refuse downloads) on
  rooted devices, where the secure storage is weaker. Add via a package like
  `flutter_jailbreak_detection`.
- **Emulator / debugger detection** — bail out if running under a debugger
  or emulator.
- **Play Integrity API** — server-side attestation that the request comes
  from a genuine, unmodified app on a genuine device.
- **Shorten TTLs further** — drop presigned URL lifetime if streaming still
  works reliably at, say, 2–3 min.

## What you cannot prevent

- A user recording their own audio output (analog hole).
- A fully determined, skilled attacker with a rooted device and time.

The goal is to make theft more expensive than it's worth for the casual
user — which these layers achieve.
