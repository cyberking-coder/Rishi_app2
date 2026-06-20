# Anurag Rishi Meditation App — Project Log

Complete record of everything built, fixed, and configured across the mobile app, admin dashboard, and Supabase backend.

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

### Home Screen
- Greeting with time-of-day (Good Morning / Afternoon / Evening)
- Featured audio grid (2-column)
- Recently Added grid
- Categories row (chips linking to browse)
- Continue Listening horizontal scroll (resumes from last position)
- Access expiry banner if ≤7 days remain
- Navigates to `/now-playing` on any audio tap

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

### Access Window System
- `access_expires_at` on each user's profile row
- `has_active_access()` checked server-side in every edge function — device clock changes cannot bypass it
- In-app access expiry screen shown when window lapses
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

### Audios Table
- Lists all audios with cover thumbnail, title, artist, duration, status
- Upload audio: file picker → presigned R2 PUT URL → upload with live progress bar
- Per-audio cover image upload
- Set `direct_url` for test-mode (bypasses R2 signing pipeline)
- Publish / unpublish audio

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

---

## 4. Bug Fixes Chronology

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
- `access_expires_at = null` means unlimited (staff/admin accounts)
- `access_expires_at` past → app shows expired screen AND edge functions block audio/downloads

---

## 6. Store Submission Status

- **Google Play**: Account in setup (DUNS number required for Organisation account — use Individual account to avoid DUNS)
- **Apple App Store**: Requires Mac for Xcode build + $99/year Apple Developer account
- APK release build: signed with keystore in `key.properties` (gitignored, keep backed up separately)
- App version: check `pubspec.yaml` → `version:` field before each store submission

---

## 7. Repository Structure

```
Rishi_app2/
├── mobile_app/              Flutter app (Dart)
│   ├── lib/
│   │   ├── app/             Theme, router, shell widgets
│   │   ├── core/            Device info, network, errors, utils
│   │   └── features/
│   │       ├── auth/        Login, forgot password, device registration
│   │       ├── home/        Home screen, categories, search
│   │       ├── audio/       Streaming, background playback, now playing
│   │       ├── downloads/   Encrypted offline downloads, offline player
│   │       ├── profile/     Profile, subscription, devices
│   │       └── access/      Access window, expiry screen, popup
│   └── android/             Android build config, keystore setup
├── admin/                   Next.js admin dashboard
│   └── src/
│       ├── app/
│       │   ├── actions/     Server actions (users, devices, content)
│       │   └── (dashboard)/ Admin pages (users, audios, categories, etc.)
│       └── components/      UI components (tables, forms, buttons)
└── supabase/
    ├── migrations/          All SQL schema migrations (numbered, ordered)
    └── functions/           Deno edge functions
        ├── issue-audio-license/
        ├── issue-playback-license/
        └── issue-upload-url/
```

---

*Last updated: June 2026*
