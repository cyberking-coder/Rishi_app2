# Publishing to Google Play & Apple App Store

A practical, step-by-step checklist for getting the Meditation app onto both
stores. Google Play is achievable from a Windows PC; the Apple App Store
**requires a Mac** (or a Mac cloud service) at build/submit time.

---

## PART A — GOOGLE PLAY STORE (Android)

### 1. Accounts & cost
- **Google Play Developer account** — one-time **$25** fee.
- Sign up at https://play.google.com/console with the org's Google account.
- Choose account type **Organization** (needs D-U-N-S-style business info) or
  **Personal**. Organization looks more trustworthy for a spiritual org.

### 2. Legal / policy prerequisites (do these early — they block release)
- **Privacy Policy URL** (required — the app collects email + device info).
  Generate at termly.io or freeprivacypolicy.com, host on a public page.
- **Data safety form** — declare what data you collect (email, device ID,
  usage) and why. Filled in Play Console.
- **Content rating questionnaire** — answer honestly; this app rates "Everyone".
- **Target audience** — select adult/teen (not "children", to avoid extra rules).
- **App access** — provide a test login (your test@ user) so Google's
  reviewers can log in past the auth wall.

### 3. Prepare store listing assets
- **App name** (max 30 chars), short description (80), full description (4000).
- **App icon** — 512×512 PNG.
- **Feature graphic** — 1024×500 PNG.
- **Screenshots** — at least 2 phone screenshots (take from a running app;
  16:9 or 9:16, min 320px).
- **Category** — "Health & Fitness" or "Lifestyle".

### 4. Build a signed release (App Bundle)
Google Play requires an **AAB** (Android App Bundle), not an APK.

1. Create a release keystore (ONE time — back it up forever):
   ```bash
   keytool -genkey -v -keystore meditation-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias meditation
   ```
2. Create `android/key.properties` (DO NOT commit it):
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=meditation
   storeFile=../meditation-release.jks
   ```
3. Wire the signing config into `android/app/build.gradle` (replace the
   debug-signing line for release with the keystore — ask Claude to do this).
4. Build:
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

> Enroll in **Play App Signing** (default) — Google manages the final signing
> key; you keep the upload key above.

### 5. Create the app in Play Console & upload
1. Play Console → **Create app** → fill name, language, free/paid.
2. Complete all the **"Set up your app"** checklist items (policy, data
   safety, content rating, target audience from step 2).
3. **Testing → Internal testing** → create a release → upload the `.aab` →
   add your own email as a tester → install via the opt-in link. Verify it
   works end to end.
4. Promote to **Closed testing** (optional, a few external testers).
5. **Production → Create release** → upload `.aab` → roll out.

### 6. Review & go live
- First review typically **1–7 days** (avg 2–3). Rejections reset the clock.
- Once approved, the app is live on Play Store. Updates = bump
  `version` in `pubspec.yaml` (e.g. `1.0.1+2`), rebuild AAB, upload.

---

## PART B — APPLE APP STORE (iOS)

> Requires a **Mac** with Xcode for the final build & upload. If you only have
> Windows, use a Mac cloud service (MacinCloud, or a CI like Codemagic /
> GitHub Actions macOS runners).

### 1. Accounts & cost
- **Apple Developer Program** — **$99 / year** (recurring, not one-time).
- Enroll at https://developer.apple.com/programs/ . Organization enrollment
  needs a **D-U-N-S number** (free, ~1–2 weeks to obtain if you don't have one).

### 2. Legal / policy prerequisites
- **Privacy Policy URL** (required).
- **App Privacy "nutrition label"** — declare data collection in App Store
  Connect (email, device ID, usage).
- **Sign-in info for review** — provide the test login; Apple reviewers are
  strict about being able to access all features.
- Apple **rejects apps that feel like a website wrapper or are too thin** —
  make sure there's real content (audios uploaded) before submitting.

### 3. Prepare store assets
- **App icon** — 1024×1024 PNG (no transparency, no rounded corners).
- **Screenshots** — required for 6.7" and 6.5" iPhones (take in the iOS
  Simulator). At least 1 per required size.
- Name (30 chars), subtitle (30), description, keywords, support URL.
- **Category** — "Health & Fitness" or "Lifestyle".

### 4. Configure the iOS project (on a Mac)
1. Generate the iOS platform folder if missing:
   ```bash
   flutter create . --platforms=ios
   ```
2. Open `ios/Runner.xcworkspace` in Xcode.
3. Set the **Bundle Identifier** (e.g. `com.meditation.app`), **Team**
   (your Apple Developer account), and a unique version/build number.
4. Add required `Info.plist` entries:
   - `NSAppTransportSecurity` (HTTPS only — already fine with Supabase/R2)
   - Background audio: under **Signing & Capabilities → Background Modes →
     Audio** (so audio plays in background — matches the Android setup).
   - `UIBackgroundModes` → `audio`.

### 5. Create the app in App Store Connect
1. https://appstoreconnect.apple.com → **My Apps → +** → New App.
2. Pick the bundle ID, name, language, SKU.
3. Fill the App Privacy, pricing (free), and the store listing assets.

### 6. Build, archive & upload
On the Mac:
```bash
flutter build ipa --release
```
Then either:
- Open the generated archive in **Xcode → Organizer → Distribute App →
  App Store Connect → Upload**, or
- Upload with **Transporter** app, or
- Automate via `xcrun altool` / Codemagic / Fastlane.

### 7. TestFlight & submit
1. The build appears in **TestFlight** after ~15–30 min of processing.
2. Test it on a real iPhone via the TestFlight app.
3. In App Store Connect → select the build → **Submit for Review**.
4. Apple review typically **1–3 days**. They may ask questions via Resolution
   Center — respond promptly.
5. On approval, either auto-release or manually release.

---

## QUICK COMPARISON

| | Google Play | Apple App Store |
|---|---|---|
| Cost | $25 once | $99 / year |
| Build OS | Windows OK | **Mac required** |
| Artifact | `.aab` | `.ipa` |
| Review time | 1–7 days | 1–3 days |
| Sideload alternative | Yes (`.apk`) | No (TestFlight only) |
| Org enrollment | Business info | **D-U-N-S number** |

---

## RECOMMENDED ORDER FOR THIS PROJECT

1. **Switch off test-mode** — set up Cloudflare R2 + real audio uploads so the
   stores see secure, real content.
2. **Android first** (cheaper, simpler, Windows-friendly) — ship to Play
   Internal Testing, then Production.
3. **iOS second** — once you have Mac access and the $99 membership.
4. Both stores need: privacy policy, real content, a working test login, and
   polished screenshots. Prepare these once and reuse.

> Claude can do all the **code/config** work (signing config, version bumps,
> iOS Info.plist, background-audio capability, build commands). The
> **accounts, payments, legal docs, and store-listing submission** are manual
> steps only you can complete.
