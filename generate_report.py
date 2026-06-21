from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, PageBreak
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from datetime import date

# ── Colour palette ────────────────────────────────────────────────────────────
VIOLET      = colors.HexColor('#8B5CF6')
DARK_VIOLET = colors.HexColor('#12082E')
PINK        = colors.HexColor('#EC4899')
MID_VIOLET  = colors.HexColor('#1C1040')
LIGHT_VIOLET= colors.HexColor('#B0A8CC')
WHITE       = colors.white
GRAY        = colors.HexColor('#4B5563')

# ── Document ──────────────────────────────────────────────────────────────────
doc = SimpleDocTemplate(
    '/home/user/Rishi_app2/KnowThyself_App_Report.pdf',
    pagesize=A4,
    leftMargin=2*cm, rightMargin=2*cm,
    topMargin=2.2*cm, bottomMargin=2.2*cm,
)

styles = getSampleStyleSheet()

def S(name, **kw):
    return ParagraphStyle(name, parent=styles['Normal'], **kw)

cover_title  = S('CT', fontSize=34, textColor=WHITE, alignment=TA_CENTER,
                 fontName='Helvetica-Bold', leading=42)
cover_sub    = S('CS', fontSize=14, textColor=LIGHT_VIOLET, alignment=TA_CENTER,
                 fontName='Helvetica', leading=20)
cover_date   = S('CD', fontSize=11, textColor=LIGHT_VIOLET, alignment=TA_CENTER)

h1  = S('H1', fontSize=18, textColor=VIOLET, fontName='Helvetica-Bold',
        spaceBefore=18, spaceAfter=6, leading=24)
h2  = S('H2', fontSize=13, textColor=VIOLET, fontName='Helvetica-Bold',
        spaceBefore=12, spaceAfter=4, leading=18)
body= S('BD', fontSize=10, textColor=colors.HexColor('#1F2937'),
        leading=15, spaceAfter=4, alignment=TA_JUSTIFY)
bull= S('BU', fontSize=10, textColor=colors.HexColor('#1F2937'),
        leading=15, leftIndent=16, bulletIndent=6, spaceAfter=3)
code= S('CO', fontSize=9, fontName='Courier', textColor=DARK_VIOLET,
        backColor=colors.HexColor('#F3F0FF'), leading=13,
        leftIndent=12, rightIndent=12, spaceBefore=4, spaceAfter=4)

def hr():  return HRFlowable(width='100%', thickness=1, color=VIOLET, spaceAfter=8, spaceBefore=4)
def sp(h=10): return Spacer(1, h)
def H1(t): return Paragraph(t, h1)
def H2(t): return Paragraph(t, h2)
def B(t):  return Paragraph(t, body)
def Li(t): return Paragraph(f'• &nbsp; {t}', bull)
def C(t):  return Paragraph(t, code)

def section_table(rows):
    t = Table(rows, colWidths=[5*cm, 11.5*cm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,-1), colors.HexColor('#EDE9FE')),
        ('TEXTCOLOR',  (0,0), (0,-1), DARK_VIOLET),
        ('FONTNAME',   (0,0), (0,-1), 'Helvetica-Bold'),
        ('FONTSIZE',   (0,0), (-1,-1), 9),
        ('FONTNAME',   (1,0), (1,-1), 'Helvetica'),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [colors.white, colors.HexColor('#F9F7FF')]),
        ('GRID',       (0,0), (-1,-1), 0.4, colors.HexColor('#DDD6FE')),
        ('VALIGN',     (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING',   (0,0), (-1,-1), 8),
    ]))
    return t

# ── COVER PAGE ────────────────────────────────────────────────────────────────
story = []

story.append(sp(60))
story.append(Paragraph('🪷', S('EMJ', fontSize=64, alignment=TA_CENTER, leading=70)))
story.append(sp(20))
story.append(Paragraph('Know Thyself', cover_title))
story.append(sp(8))
story.append(Paragraph('Meditation & Spiritual Audio Streaming App', cover_sub))
story.append(sp(6))
story.append(Paragraph('Full Project Documentation Report', cover_sub))
story.append(sp(40))
story.append(HRFlowable(width='60%', thickness=2, color=VIOLET,
                        hAlign='CENTER', spaceAfter=16))
story.append(Paragraph('Anurag Rishi — Find Peace Within', cover_sub))
story.append(sp(10))
story.append(Paragraph(f'Report Date: {date.today().strftime("%d %B %Y")}', cover_date))
story.append(sp(10))
story.append(Paragraph('Version 1.0 — Release Build', cover_date))

story.append(PageBreak())

# ── 1. PROJECT OVERVIEW ───────────────────────────────────────────────────────
story.append(H1('1. Project Overview'))
story.append(hr())
story.append(B('Know Thyself (formerly Anurag Rishi) is a Flutter-based mobile application '
               'for Android that delivers meditation, spiritual talks, and guided audio sessions. '
               'The app features a fully dark-violet themed UI, offline download capabilities '
               'with AES-256-CTR encryption, a one-device-per-account lock for DRM, background '
               'audio playback, Supabase-powered backend, and an admin dashboard for user/content management.'))
story.append(sp(8))
story.append(section_table([
    ['App Name',        'Know Thyself'],
    ['Previous Name',   'Anurag Rishi'],
    ['Platform',        'Android (Flutter)'],
    ['Backend',         'Supabase (PostgreSQL + Edge Functions + Auth + Storage)'],
    ['Storage',         'Cloudflare R2 (private bucket, signed URLs)'],
    ['Build Target',    'Release APK — flutter build apk --release'],
    ['Design Theme',    'Dark violet (#12082E background, #8B5CF6 accent, #EC4899 pink)'],
    ['Architecture',    'Feature-first, Riverpod state management, Repository pattern'],
]))

story.append(PageBreak())

# ── 2. TECH STACK ─────────────────────────────────────────────────────────────
story.append(H1('2. Technology Stack'))
story.append(hr())

story.append(H2('2.1 Frontend — Flutter'))
story.append(section_table([
    ['Flutter',             '3.x — cross-platform UI toolkit'],
    ['Dart',                '3.3+ — language with null safety'],
    ['flutter_riverpod',    '^2.5.1 — reactive state management (Providers, FutureProviders, StateProviders)'],
    ['go_router',           '^14.2.0 — declarative routing with auth redirect guards'],
    ['just_audio',          '^0.9.40 — audio playback engine'],
    ['audio_service',       '^0.18.15 — background audio + Android notification controls'],
    ['flutter_secure_storage', '^9.2.2 — encrypted key-value store for device salt & download keys'],
    ['device_info_plus',    '^10.1.0 — hardware device identifiers for fingerprinting'],
    ['path_provider',       '^2.1.4 — filesystem paths for encrypted download storage'],
    ['http',                '^1.2.2 — HTTP client for proxy requests'],
    ['pointycastle',        '^3.9.1 — AES-256-CTR decryption for offline playback'],
    ['crypto',              '^3.0.3 — SHA-256 device fingerprint hashing'],
    ['rxdart',              '^0.27.7 — stream composition for audio state'],
    ['flutter_launcher_icons', '^0.13.1 — automated launcher icon generation'],
]))
story.append(sp(8))

story.append(H2('2.2 Backend — Supabase'))
story.append(section_table([
    ['Supabase Auth',       'Email/password authentication, session management, JWT tokens'],
    ['PostgreSQL',          'Primary database — users, audio content, categories, subscriptions, devices'],
    ['Row Level Security',  'RLS policies ensuring users only access their own data'],
    ['Edge Functions',      'Deno serverless functions for audio stream signing, access verification'],
    ['Realtime',            'Auth state change streams consumed by GoRouter redirect guard'],
    ['Project Ref',         'gzcanqovqirarnculqjq'],
]))
story.append(sp(8))

story.append(H2('2.3 Storage — Cloudflare R2'))
story.append(section_table([
    ['Bucket Type',     'Private — no public access'],
    ['Access Method',   'Time-limited signed URLs generated by Supabase Edge Functions'],
    ['Content',         'Encrypted audio files (MP3/M4A)'],
    ['Security',        'Audio URLs expire after short window; re-signed on each play request'],
]))
story.append(sp(8))

story.append(H2('2.4 Architecture Pattern'))
story.append(Li('Feature-first folder structure: each feature has its own domain / data / presentation / application layers'))
story.append(Li('Repository pattern: abstract interfaces in domain, concrete implementations in data layer'))
story.append(Li('Riverpod Providers wire everything together — no service locators or singletons'))
story.append(Li('GoRouter handles all navigation with declarative route guards based on auth state'))

story.append(PageBreak())

# ── 3. FEATURES BUILT ─────────────────────────────────────────────────────────
story.append(H1('3. Features Built'))
story.append(hr())

story.append(H2('3.1 Splash Screen'))
story.append(Li('Dark violet radial gradient background'))
story.append(Li('Glowing lotus logo with animated fade-in and scale-up (1.4 s animation)'))
story.append(Li('"Anurag Rishi / Find Peace Within" wordmark centred on screen'))
story.append(Li('Auto-routes to /home or /login after 2.6 s based on active session'))
story.append(Li('Router guard prevents mid-animation redirect away from splash'))
story.append(sp(6))

story.append(H2('3.2 Authentication'))
story.append(Li('Login screen with email/password via Supabase Auth'))
story.append(Li('Forgot Password screen'))
story.append(Li('Auth state streamed into GoRouter — automatic redirect on login/logout'))
story.append(Li('One-device-per-account lock: device registers on login; second device blocked'))
story.append(Li('Admin can "Reset Device" to allow user to re-register on new device'))
story.append(sp(6))

story.append(H2('3.3 Home Screen'))
story.append(Li('Dark violet themed — background #12082E, cards #221550'))
story.append(Li('Real username greeting pulled from Supabase profile'))
story.append(Li('Daily Card: first featured audio with cover art and Play Now button'))
story.append(Li('Featured For You: horizontal scrollable row of audio cards'))
story.append(Li('Categories row: colour-coded icons, tap navigates to filtered browse'))
story.append(Li('Continue Listening bar: resumes last in-progress audio with progress indicator'))
story.append(Li('Search bar navigates to Browse/Search screen'))
story.append(sp(6))

story.append(H2('3.4 Browse / Search Screen'))
story.append(Li('Dual mode: search (with live text field) or category filter'))
story.append(Li('Audio rows with gradient thumbnail, title, artist, duration'))
story.append(Li('Tap any audio — starts streaming immediately, navigates to Now Playing'))
story.append(sp(6))

story.append(H2('3.5 Now Playing Screen'))
story.append(Li('Full dark violet design with glowing album art ring'))
story.append(Li('Seek bar with mm:ss / h:mm:ss formatting'))
story.append(Li('Play / Pause / Previous / Next transport controls'))
story.append(Li('Repeat and Shuffle toggles (highlight violet when active)'))
story.append(Li('Favourite heart toggle (pink when active)'))
story.append(Li('Sleep timer with countdown display'))
story.append(Li('Playback speed selector (0.5× – 2×)'))
story.append(Li('Download button to save audio for offline use'))
story.append(sp(6))

story.append(H2('3.6 Offline Downloads'))
story.append(Li('AES-256-CTR encryption — audio stored encrypted on device, never as plaintext'))
story.append(Li('Loopback decrypting proxy (127.0.0.1) serves decrypted bytes to just_audio'))
story.append(Li('Downloads screen lists all downloads with live status (queued / downloading / paused / completed / failed)'))
story.append(Li('Pause, resume, delete actions per download'))
story.append(Li('Offline Player screen: plays encrypted local file, seek bar, play/pause — fully dark themed'))
story.append(Li('Downloads survive app restart (metadata persisted, restored on boot)'))
story.append(Li('Expired/revoked downloads purged automatically on startup'))
story.append(sp(6))

story.append(H2('3.7 Profile Screen'))
story.append(Li('Dark violet circular gradient avatar'))
story.append(Li('Display name + plan badge (👑 Premium Member)'))
story.append(Li('Stats row: Day Streak / Minutes / Sessions'))
story.append(Li('Achievements section with 4 badge icons (🏆 💎 🔥 🌿)'))
story.append(Li('Subscription row showing plan name'))
story.append(Li('Settings button opens bottom sheet with: Logout, Device Info'))
story.append(sp(6))

story.append(H2('3.8 Mini Player (Footer Bar)'))
story.append(Li('Persistent across Home, Downloads, Profile screens via AppShell wrapper'))
story.append(Li('Dark violet surface (#1C1040) — matches app theme'))
story.append(Li('Shows album art thumbnail, title, artist, play/pause button'))
story.append(Li('Thin violet progress bar at top'))
story.append(Li('Tap navigates to full Now Playing screen'))
story.append(sp(6))

story.append(H2('3.9 App Identity'))
story.append(Li('App name: Know Thyself (AndroidManifest + AppConfig)'))
story.append(Li('Launcher icon: custom lotus image (assets/app_icon.png via flutter_launcher_icons)'))
story.append(Li('Adaptive icon with dark violet (#12082E) background'))

story.append(PageBreak())

# ── 4. DATABASE SCHEMA ────────────────────────────────────────────────────────
story.append(H1('4. Database Schema (Supabase / PostgreSQL)'))
story.append(hr())

story.append(section_table([
    ['profiles',        'User profile — displayName, email, role, subscriptionTier, country, status, avatarUrl, access_expires_at'],
    ['audios',          'Audio content — title, artist, cover_art_url, duration_seconds, is_premium, status, play_count, created_at'],
    ['categories',      'Browse categories — name, slug, sort_order'],
    ['audio_categories','Many-to-many join: audios ↔ categories'],
    ['subscriptions',   'User subscriptions — plan, status, current_period_end, cancel_at_period_end'],
    ['subscription_plans', 'Plan definitions — name, price, duration'],
    ['devices',         'Registered devices — user_id, device_fingerprint, device_name, platform, is_active'],
    ['watch_history',   'Playback progress — user_id, audio_id, progress_seconds, duration_seconds, completed, last_watched_at'],
    ['favorites',       'User favourite audio items'],
]))
story.append(sp(8))

story.append(H2('Key RPCs / Edge Functions'))
story.append(Li('has_active_access() — server-side RPC checks if user has valid access window'))
story.append(Li('register_device — validates one-device lock, registers new device fingerprint'))
story.append(Li('Audio stream signing edge function — generates time-limited Cloudflare R2 signed URL'))

story.append(PageBreak())

# ── 5. PROBLEMS FACED & SOLUTIONS ─────────────────────────────────────────────
story.append(H1('5. Problems Faced & Solutions'))
story.append(hr())

problems = [
    ('Cross-Drive Kotlin Build Crash (Windows)',
     'Project on D: drive, Flutter pub cache on C: drive. Kotlin incremental compiler failed with '
     '"this and base files have different roots" error during Gradle build.',
     'Added kotlin.incremental=false to mobile_app/android/gradle.properties. '
     'This disables Kotlin\'s incremental compilation, bypassing the cross-drive path resolution bug.'),

    ('Audio Not Playing After Device Reset',
     'After admin used "Reset All Devices" in the admin panel, all users lost audio/download '
     'access. _getActiveDeviceId() returned null → 403 Forbidden from edge functions.',
     'The fix is operational: users must log out and log back in after a device reset. '
     'Re-login triggers register_device RPC which creates a new active device row.'),

    ('Specific User (test@test.com) Always Failing',
     'One test account had a stale active device row from a different emulator/physical device. '
     'Even after reset, the old fingerprint caused 403 errors on that account only.',
     'Admin panel → ••• menu → "Reset device" on the specific user → user logs back in. '
     'Added per-user reset button to admin panel for targeted device unlock.'),

    ('Splash Screen Not Centred',
     'Opening screen used Spacer(flex:5) above/below lotus and another Spacer(flex:2) above '
     'the wordmark, pushing logo to top-third and text to bottom — visually off-balance.',
     'Replaced the Spacer-based Column with a single Center widget wrapping all elements '
     'in a Column(mainAxisSize: min). All content now sits perfectly centred on screen.'),

    ('Mini Player Footer White / Wrong Theme',
     'MiniPlayer widget used AppTheme.surfaceElevated (light cream colour) as its background, '
     'making the footer bar appear white — jarring against the dark violet screens.',
     'Replaced AppTheme references in mini_player.dart with hardcoded dark violet constants '
     '(#1C1040 background, #8B5CF6 accent, white text). Now matches the rest of the app.'),

    ('num vs double Type Error in Seek Bar',
     'Dart\'s double.clamp(double, double) returns num, not double. The Slider widget '
     'requires a double for its value: parameter, causing a compile-time type error.',
     'Added .toDouble() after the clamp() call, then cast the result as double. '
     'This satisfies Dart\'s strict type system without changing any runtime behaviour.'),

    ('Git Merge Conflicts on gradle.properties',
     'Local Windows machine had uncommitted edits to gradle.properties (the kotlin.incremental=false '
     'fix). git pull failed repeatedly due to unmerged files and vim editor opening for merge commit.',
     'Used git stash → pull → stash pop workflow. When vim opened for merge message, '
     'used :wq to save and exit. Then used git reset --hard origin/branch to sync cleanly.'),

    ('UI Regression After Revert',
     'Early in the project, UI redesign caused lag/instability. Full revert to commit 991734c '
     'was performed, which also deleted browse_screen.dart (a new file added during redesign).',
     'Recreated browse_screen.dart from scratch with the dark violet theme. '
     'Router was updated to add /search and /category/:id routes pointing to the new file.'),
]

for i, (title, problem, solution) in enumerate(problems, 1):
    story.append(H2(f'5.{i}  {title}'))
    data = [
        ['Problem', problem],
        ['Solution', solution],
    ]
    t = Table(data, colWidths=[3*cm, 13.5*cm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (0,0), colors.HexColor('#FEE2E2')),
        ('BACKGROUND', (0,1), (0,1), colors.HexColor('#D1FAE5')),
        ('FONTNAME',   (0,0), (0,-1), 'Helvetica-Bold'),
        ('FONTSIZE',   (0,0), (-1,-1), 9),
        ('FONTNAME',   (1,0), (1,-1), 'Helvetica'),
        ('VALIGN',     (0,0), (-1,-1), 'TOP'),
        ('GRID',       (0,0), (-1,-1), 0.4, colors.HexColor('#E5E7EB')),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING',   (0,0), (-1,-1), 8),
    ]))
    story.append(t)
    story.append(sp(10))

story.append(PageBreak())

# ── 6. SECURITY MODEL ─────────────────────────────────────────────────────────
story.append(H1('6. Security Model'))
story.append(hr())

story.append(H2('6.1 One-Device Lock (DRM)'))
story.append(Li('On login, app generates a SHA-256 device fingerprint from hardware ID + secure random salt'))
story.append(Li('Salt stored in FlutterSecureStorage (survives reinstall on iOS Keychain)'))
story.append(Li('register_device RPC checks if another active device exists for the user'))
story.append(Li('If yes, registration is denied — user sees "already logged in on another device"'))
story.append(Li('Admin can reset a user\'s device from the admin panel'))
story.append(sp(6))

story.append(H2('6.2 Encrypted Offline Storage'))
story.append(Li('Audio files downloaded and stored with AES-256-CTR encryption'))
story.append(Li('Encryption key unique per download, stored in FlutterSecureStorage'))
story.append(Li('Playback: local loopback proxy (127.0.0.1) decrypts on-the-fly into just_audio'))
story.append(Li('No plaintext audio file ever written to disk'))
story.append(Li('On subscription expiry, purgeRevokedAndExpired() deletes local files'))
story.append(sp(6))

story.append(H2('6.3 Network Security'))
story.append(Li('Cloudflare R2 bucket is private — no public URLs'))
story.append(Li('Time-limited signed URLs generated per request by Supabase Edge Function'))
story.append(Li('Supabase RLS policies enforce per-user data isolation at database level'))
story.append(Li('has_active_access() RPC validated server-side before any stream URL is issued'))

story.append(PageBreak())

# ── 7. FILE STRUCTURE ─────────────────────────────────────────────────────────
story.append(H1('7. Project File Structure'))
story.append(hr())

story.append(C(
'mobile_app/\n'
'├── android/\n'
'│   ├── app/src/main/AndroidManifest.xml   ← app name, permissions\n'
'│   └── gradle.properties                  ← kotlin.incremental=false fix\n'
'├── assets/\n'
'│   └── app_icon.png                       ← launcher icon (lotus)\n'
'├── lib/\n'
'│   ├── main.dart                          ← app entry, Riverpod scope, theme\n'
'│   ├── app/\n'
'│   │   ├── router/app_router.dart         ← GoRouter, auth guards, all routes\n'
'│   │   ├── theme/app_theme.dart           ← light + dark ThemeData\n'
'│   │   └── widgets/\n'
'│   │       ├── app_shell.dart             ← wraps screens with MiniPlayer\n'
'│   │       └── lotus_logo.dart            ← custom lotus SVG widget\n'
'│   ├── core/\n'
'│   │   ├── config/app_config.dart         ← Supabase URL, keys, app name\n'
'│   │   ├── device/device_info_service.dart\n'
'│   │   └── network/supabase_client_provider.dart\n'
'│   └── features/\n'
'│       ├── auth/                          ← login, splash, auth providers\n'
'│       ├── audio/                         ← player handler, now playing, mini player\n'
'│       ├── downloads/                     ← encrypted downloads, offline player\n'
'│       ├── home/                          ← home screen, browse, search\n'
'│       └── profile/                       ← profile screen, settings sheet\n'
'supabase/\n'
'└── functions/                             ← Deno edge functions (stream signing)\n'
'PROJECT_LOG.md                             ← full operational log\n'
))

story.append(PageBreak())

# ── 8. SCREENS SUMMARY ───────────────────────────────────────────────────────
story.append(H1('8. Screens Summary'))
story.append(hr())

screens = [
    ['Screen', 'Route', 'Key Components'],
    ['Splash', '/splash', 'Animated lotus, auto-navigate to home/login'],
    ['Login', '/login', 'Email/password, forgot password link'],
    ['Forgot Password', '/forgot-password', 'Supabase password reset email'],
    ['Home', '/home', 'Greeting, daily card, featured, categories, continue listening'],
    ['Browse / Search', '/search', 'Live text search over audios'],
    ['Category Browse', '/category/:id', 'Filtered audio list by category'],
    ['Now Playing', '/now-playing', 'Full player, seek, controls, download, timer'],
    ['Downloads', '/downloads', 'Download queue with status and actions'],
    ['Offline Player', '/offline-player/:id', 'Encrypted local playback'],
    ['Profile', '/profile', 'Avatar, stats, achievements, settings sheet'],
]

t = Table(screens, colWidths=[4*cm, 4.5*cm, 8*cm])
t.setStyle(TableStyle([
    ('BACKGROUND',    (0,0), (-1,0), VIOLET),
    ('TEXTCOLOR',     (0,0), (-1,0), WHITE),
    ('FONTNAME',      (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE',      (0,0), (-1,-1), 9),
    ('FONTNAME',      (0,1), (-1,-1), 'Helvetica'),
    ('ROWBACKGROUNDS',(0,1), (-1,-1), [WHITE, colors.HexColor('#F5F3FF')]),
    ('GRID',          (0,0), (-1,-1), 0.4, colors.HexColor('#DDD6FE')),
    ('VALIGN',        (0,0), (-1,-1), 'TOP'),
    ('TOPPADDING',    (0,0), (-1,-1), 5),
    ('BOTTOMPADDING', (0,0), (-1,-1), 5),
    ('LEFTPADDING',   (0,0), (-1,-1), 7),
]))
story.append(t)

story.append(PageBreak())

# ── 9. GIT / BRANCH INFO ──────────────────────────────────────────────────────
story.append(H1('9. Repository & Version Control'))
story.append(hr())
story.append(section_table([
    ['Repository',      'github.com/cyberking-coder/Rishi_app2'],
    ['Working Branch',  'claude/funny-keller-sbua4r'],
    ['Base Commit',     '991734c — Last stable state (pre-redesign)'],
    ['Final Commit',    'b65c129+ — Know Thyself full release'],
    ['Key Commits',     '991734c Revert to stable → splash → now playing → home → profile → bug fixes → rename'],
]))
story.append(sp(8))
story.append(B('All development was done on the feature branch claude/funny-keller-sbua4r. '
               'The branch was built incrementally: revert to stable baseline → splash screen → '
               'now playing redesign → home screen redesign → browse/search → profile redesign → '
               'theme fixes (downloads, mini player, offline player) → app rename → launcher icon setup.'))

story.append(PageBreak())

# ── 10. HOW TO BUILD ──────────────────────────────────────────────────────────
story.append(H1('10. Build & Run Instructions'))
story.append(hr())

story.append(H2('Prerequisites'))
story.append(Li('Flutter SDK 3.x installed and on PATH'))
story.append(Li('Android SDK with a connected device or emulator'))
story.append(Li('Java 17+ (for Gradle)'))
story.append(Li('Git'))
story.append(sp(6))

story.append(H2('Clone & Setup'))
story.append(C(
'git clone https://github.com/cyberking-coder/Rishi_app2.git\n'
'cd Rishi_app2\n'
'git checkout claude/funny-keller-sbua4r\n'
'cd mobile_app\n'
'flutter pub get'
))
story.append(sp(6))

story.append(H2('Generate Launcher Icons (one-time)'))
story.append(C('dart run flutter_launcher_icons'))
story.append(sp(6))

story.append(H2('Debug Run'))
story.append(C('flutter run'))
story.append(sp(6))

story.append(H2('Release APK'))
story.append(C('flutter build apk --release\n'
               '# Output: build/app/outputs/flutter-apk/app-release.apk'))
story.append(sp(6))

story.append(H2('Windows-specific Note'))
story.append(B('If the project and Flutter pub cache are on different drives (e.g. project on D:, '
               'pub cache on C:), Kotlin incremental compilation will crash. The fix is already '
               'committed — gradle.properties contains kotlin.incremental=false.'))

story.append(PageBreak())

# ── 11. KNOWN LIMITATIONS ─────────────────────────────────────────────────────
story.append(H1('11. Known Limitations & Future Work'))
story.append(hr())

story.append(section_table([
    ['Day Streak tracking',     'Always shows 0 — daily usage not tracked in watch_history. Needs a daily_streaks table or RPC.'],
    ['Minutes / Sessions stats','Always show 0 — aggregate queries not yet implemented. Can be derived from watch_history.'],
    ['Gender-based avatar',     'Profile uses a generic person icon. UserProfile entity has no gender field. Would need a DB column and UI selector.'],
    ['iOS support',             'Not configured — no iOS provisioning profile, no Info.plist changes. Straightforward to add.'],
    ['Gradle version warnings', 'AGP 8.9.1 and Gradle 8.12.0 are below Flutter\'s upcoming minimum. Should upgrade to AGP 8.11.1+ / Gradle 8.14+.'],
    ['Push notifications',      'Not implemented. Could use Supabase Realtime or Firebase Cloud Messaging for new content alerts.'],
    ['Chromecast / AirPlay',    'Not implemented. just_audio supports cast on some platforms with additional setup.'],
]))

story.append(PageBreak())

# ── FINAL PAGE ────────────────────────────────────────────────────────────────
story.append(sp(80))
story.append(HRFlowable(width='80%', thickness=2, color=VIOLET, hAlign='CENTER'))
story.append(sp(20))
story.append(Paragraph('Know Thyself', S('FT', fontSize=28, textColor=DARK_VIOLET,
                                          fontName='Helvetica-Bold', alignment=TA_CENTER)))
story.append(sp(8))
story.append(Paragraph('Anurag Rishi — Find Peace Within', S('FS', fontSize=13,
                        textColor=GRAY, alignment=TA_CENTER)))
story.append(sp(10))
story.append(Paragraph(f'© {date.today().year}  ·  All rights reserved',
                        S('FC', fontSize=10, textColor=GRAY, alignment=TA_CENTER)))

# ── BUILD ─────────────────────────────────────────────────────────────────────
doc.build(story)
print("PDF generated: KnowThyself_App_Report.pdf")
