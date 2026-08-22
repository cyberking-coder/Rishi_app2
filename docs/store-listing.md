# Store listing copy — Know Thyself 2.1.1

Everything the two stores ask for, in the order they ask for it. Replaces
the 1.x `play-store-listing.md`, which still described a dark-violet
interface, an audio-only app and deletion by email — none of which are
true any more.

Character limits are the stores' own. Where a field is at its limit it is
marked, so an edit does not silently overflow and get truncated mid-word.

- **iOS bundle ID:** `com.anuragrishi.knowthyself`
- **Android package:** `com.knowthyself.app`
- **Version:** 2.1.1 (build 14)

---

## 1. Shared facts

| Field | Value |
|---|---|
| Support email | ar.happinessmovement@gmail.com |
| Privacy policy | https://pay.anuragrishi.com/privacy |
| Terms of use | https://pay.anuragrishi.com/terms |
| Refund policy | https://pay.anuragrishi.com/refunds |
| Support / contact | https://pay.anuragrishi.com/contact |
| Account deletion | https://pay.anuragrishi.com/delete-account |
| Category | Health & Fitness (secondary: Lifestyle) |
| Age rating | 4+ / Everyone |

---

## 2. Apple App Store Connect

### App name (30 max)
```
Know Thyself
```

### Subtitle (30 max — this is 28)
```
Meditation & Inner Stillness
```

### Promotional text (170 max — editable without a new build)
```
New: ask the guide anything, in English, Hindi or Marathi — by voice or by typing. Plus guided video series, live sessions with Anurag Rishi, and offline listening.
```

### Description (4000 max)

> **Apple copy only.** Play keeps the course wording further down — Android is
> not claiming the reader-app exception and has nothing to gain from the
> reframing. The words here are chosen against Guideline 3.1.3(a), which
> enumerates magazines, newspapers, books, audio, music and video and says
> nothing about education: "course", "lesson" and "certificate" are the three
> that invite the reviewer to file this under the one category the exception
> does not cover.

```
Know Thyself — Find Peace Within

A quiet place to return to, guided by Anurag Rishi. Whether you are looking for
calm after a long day, deeper focus, rest that actually restores, or simply a
few honest minutes with yourself, Know Thyself gives you something worth
listening to and someone to ask.

ASK THE GUIDE

A companion that knows the whole library and where you are in it. Ask it how to
sit with a restless mind, what to play tonight, or what a teaching meant — in
English, Hindi or Marathi, typed or spoken aloud. Tap the microphone and talk
normally; it listens, understands and answers. Dictation uses your phone's own
speech recognition, so nothing you say is recorded or uploaded by us.

GUIDED MEDITATIONS AND TALKS

Spoken sessions to relax, refocus and reconnect, alongside talks and teachings
that bring clarity rather than noise. Browse by category or search for what you
need in the moment.

VIDEO SERIES

Guided series that build episode by episode. The next one opens as you go, your
place is remembered, and the readings and audio that belong with an episode sit
alongside it.

LIVE SESSIONS

Join Anurag Rishi live. Sessions appear in the app with the time in your
calendar, you are reminded before they begin, and the joining link arrives when
it is time.

LISTEN ANYWHERE

Download anything to your device and play it with no signal at all — on a
plane, on the underground, in the hills. Playback continues with the screen off
and with other apps open, with controls in your notification shade and on your
lock screen. A sleep timer fades the audio out on its own so you do not have to
stay awake to stop it.

IT REMEMBERS WHERE YOU WERE

Close the app mid-session and open it a week later; it picks up at the same
second. Your progress, your downloads and your place in every series follow
your account.

MADE TO BE CALM

A soft, uncluttered interface built for someone who is trying to settle, not
someone who is trying to be entertained. No streaks to protect, no badges
demanding attention, nothing flashing for your time.

YOUR ACCOUNT IS YOURS

Sign in with Apple, Google or an email address. Delete your account and
everything in it from inside the app, in two taps, whenever you want.

WHY KNOW THYSELF

In a loud and fast world, peace is not something to be found somewhere else.
This is a daily companion for the work of turning inward — a place to breathe,
reflect and come back to yourself.

— Find Peace Within —

Terms of use: https://pay.anuragrishi.com/terms
Privacy policy: https://pay.anuragrishi.com/privacy
```

### Keywords (100 max, comma-separated, no spaces after commas — this is 97)
```
meditation,mindfulness,calm,sleep,relax,spiritual,anxiety,breathe,guided,peace,healing,yoga,hindi
```
> Do not repeat words already in the name or subtitle — Apple indexes those
> separately and a duplicate wastes characters. That is why "know", "thyself"
> and "stillness" are absent.

### What's New in This Version (4000 max)

Features **and** fixes together, deliberately. Build 13 was pulled from
review before it rolled out, so nobody ever received 2.1.0 — for everyone
installing 2.1.1 this is the release that brings the guide, the redesign and
Sign in with Apple. Fix-only notes would describe a version they never had.

```
• Ask the guide — a companion that knows the whole library and where you are
  in it. Ask how to sit with a restless mind or what to play tonight, in
  English, Hindi or Marathi. Type it, or tap the microphone and just talk.
• A completely new look: softer, quieter, easier to read.
• Live sessions you can register for and join from inside the app.
• Sign in with Apple.
• Delete your account and everything in it from Profile → Settings, at any
  time, in two taps.

Also in this update:

• Fixed downloaded audio disappearing. Saving something and then returning to
  the home screen could remove everything you had downloaded. Your downloads
  now stay on your device until you delete them yourself. If any vanished
  before this update they will need downloading again — the files were removed
  and cannot be recovered.
• The short freeze on the home screen was the same fault, and is gone with it.
• The download button on the player is now clearly visible. It was being drawn
  in a dark colour against the dark player background and was easy to miss.
• The membership page opens reliably, and now says what went wrong on the rare
  occasion it cannot.
```
> The line about downloads being unrecoverable is not padding. Anyone who lost
> them will reopen the app expecting them back; saying so here is cheaper than
> the support mail that follows if we do not.

### App Review Information → Notes
```
READER APP — GUIDELINE 3.1.3(a)
Know Thyself is a reader app. It provides guided meditation audio,
recorded talks, and video series from Anurag Rishi. People acquire
access outside the app; the app signs them in and plays what their
account already holds.

This build contains no purchase mechanism of any kind. There are no
prices anywhere in the app, no purchase or subscribe buttons, no
checkout, and no buttons, links or calls to action of any kind that
direct a customer to a purchasing mechanism outside the app.

Content the signed-in account does not hold is shown with a lock and no
price. Selecting it explains that access is required and offers no way
to obtain it. The in-app assistant does not describe how to obtain
access, name any price, or reference any website.

WHAT CHANGED SINCE THE PREVIOUS SUBMISSION
The previous submission was made without review information, so it was
assessed without the context above. That was our omission.

We have also removed everything that was not the playing of previously
acquired content. Live sessions have been removed entirely, so the app
facilitates no real-time or person-to-person services. Completion
certificates have been removed, so the app issues no credentials. What
remains is a library of audio and video, and a player for it.

DEMO ACCOUNT
The account in Sign-In Information has active access, so every screen is
reachable without any purchase. Please use it — a new free account sees
only locked content, which is not the full experience.

ONE-DEVICE SIGN-IN
The app permits one device per account at a time, as a licence-sharing
control. If the account is signed in elsewhere, signing in releases the
previous session; if a device error appears, signing in again clears it.

HOW TO REACH EACH FEATURE
  • Ask the guide — Home tab, the "Ask the guide" row under the search
    bar. The microphone is at the right of the message box. It needs the
    microphone permission and a network connection.
  • Video series — Videos tab. The demo account has access to all of them.
  • Offline playback — the download control on any item, then Downloads.
  • Account deletion — Profile tab → Settings → Delete account. This
    deletes the account immediately and cannot be undone, so please use a
    throwaway signup rather than the demo account if you want to test it.

MICROPHONE
Requested only when the user taps the microphone in the guide, for
dictation. Speech recognition runs on the device through the system
recogniser; no audio is recorded to a file or transmitted by the app.
```

### Sign in with Apple
Required, and implemented — the app offers Google Sign-In, which triggers
Guideline 4.8. Confirm before submitting that the capability is enabled on
the App ID in the Developer portal, or the button fails at runtime with an
opaque authorisation error.

---

### TestFlight → Test Information (Beta App Review)

Separate from App Review Notes above, and asked for once before the first
external test. The Beta App Description is shown to **testers** inside
TestFlight, so it is written for them rather than for a reviewer — but the
beta reviewer reads it too, which is why it uses the same vocabulary as the
App Store description and does not mention buying anything. See Section 7 on
Guideline 3.1.3(a): a purchase call to action in this field would be one in
the submission.

**Beta App Description** (4000 max)
```
Know Thyself is a guided meditation app — spoken sessions, talks and video
series from Anurag Rishi, with a companion you can ask for something to play.

This build is for testing before release. Please try:

  • Sign in with email, Google or Apple, and check you land on the home screen.
  • Play a guided meditation. Lock the phone and confirm playback continues,
    with controls on the lock screen.
  • Download something, turn on Airplane Mode, and play it back.
  • Open the Videos tab and watch an episode of a series.
  • Ask the guide a question — type it, then tap the microphone and speak it.
    Dictation needs the microphone permission; speech recognition runs on
    your own device.
  • Set a sleep timer and confirm the audio fades out on its own.
  • Home tab → Live sessions, if one is scheduled.
  • Profile → Settings → Delete account. Please use a throwaway signup for
    this rather than the test account below, since it cannot be undone.

Notes:

  • One account works on one device at a time. Signing in on a second device
    releases the first — if you see a device error, sign in again and it will
    clear.
  • The test account below already has full access, so nothing in the app
    will ask you for payment.
  • Report anything odd to the feedback email, or shake the device to send a
    screenshot through TestFlight.
```

**Feedback Email**: `ar.happinessmovement@gmail.com`

**Contact Information**: the Account Holder's own name, phone and email —
Apple uses these to reach a person about the beta, and they are not shown to
testers. CONFIRM against `admin/src/lib/legal.ts`, whose phone number is still
a placeholder.

**Sign-In Information**: tick *Sign-in required* and give the same demo
account as App Review Notes above. It **must have active access** — a tester
or reviewer who can only reach locked screens reports the app as broken, which
is the most common way this step fails.

---

## 3. Google Play Console

### App name (30 max)
```
Know Thyself
```

### Short description (80 max — this is 69)
```
Guided meditation, courses and a companion to ask. Find peace within.
```

### Release notes — 2.1.1 (build 14) (500 max — this is 479)
```
• Ask the guide — a companion that knows the whole library and your progress. Type, or tap the microphone and speak, in English, Hindi or Marathi.
• A softer, calmer new look throughout.
• Live sessions you can register for and join from inside the app.
• Delete your account and all your data from Profile → Settings.
• Fixed downloads disappearing after a return to the home screen, and the brief freeze that came with it.
• The player's download button is now clearly visible.
```
> Play caps release notes at 500 characters per language and truncates
> silently rather than warning, so this is a compressed version of the App
> Store text — same order, features before fixes. Sign in with Apple is the
> line that had to go: it is the least relevant of them on Android.

### Full description (4000 max)
Use the App Store description above verbatim; it is within Play's limit and
breaks no Play rule. Play does not allow performance claims or references to
other stores, and there are none.

### Data safety form

Collected, and **not shared with anyone**:

| Data type | Collected | Purpose | Required? |
|---|---|---|---|
| Name | Yes | Account management | Optional |
| Email address | Yes | Account management, App functionality | Required |
| User IDs | Yes | Account management | Required |
| Device or other IDs | Yes | App functionality (one-device sign-in), Fraud prevention | Required |
| App interactions (playback and lesson progress) | Yes | App functionality (resume where you left off) | Required |
| Other in-app messages (guide conversations) | Yes | App functionality | Optional |
| Purchase history | Yes | App functionality | Optional |
| Microphone audio | **No** | — | — |

Answers to the yes/no questions:
- Is all data encrypted in transit? **Yes**
- Can users request that data be deleted? **Yes**
- Data deletion URL: `https://pay.anuragrishi.com/delete-account`

> The microphone line is the one people get wrong. The app holds the
> `RECORD_AUDIO` permission, but dictation goes to the system recogniser and
> the app never receives, stores or transmits a recording — so audio is not
> "collected" in Play's sense. Declaring it as collected would be inaccurate
> in the other direction and would demand a retention answer that does not
> exist.

### App access (App content → App access)
```
All functionality requires signing in.

  Email:    <FILL IN>
  Password: <FILL IN>

This account has an active membership, so paid courses and live sessions are
reachable without paying. The app permits one signed-in device per account; if
a sign-in is refused, sign in again and the previous session is cleared.

Account deletion is at Profile → Settings → Delete account, and is immediate
and permanent — please use a fresh signup to test it rather than the account
above.
```

### Ads
Contains ads: **No**.

### Content rating questionnaire
No violence, no sexual content, no profanity, no gambling, no user-generated
content shared between users. The guide is an AI assistant whose replies are
visible only to the person who asked. Expected outcome: **Everyone / 3+**.

### Government apps / financial features
Not a financial app. Payments are for the app's own digital content, taken on
an external web page by a licensed gateway.

### Target audience
18 and over. The app is not directed at children, so no Families policy
declarations apply.

---

## 4. Graphic assets

| Asset | Size | Status |
|---|---|---|
| App icon (Play) | 512 × 512 PNG | existing lotus icon |
| Feature graphic (Play) | 1024 × 500 PNG | **needed** |
| Phone screenshots (Play) | 2–8, long side ≤ 2× short side | the 738 × 1600 captures are fine as-is |
| iPhone 6.7"/6.5" (App Store) | 1284 × 2778 | `appstore_screenshots/1284x2778/` |
| iPad 13" (App Store) | 2064 × 2752 | only if the app is offered for iPad |

> The App Store sizes are ~2.16:1 and therefore **rejected by Play**, which
> caps a phone screenshot's long side at twice its short side. The two stores
> need different files; do not reuse one set for both.

---

## 5. Before pressing submit

> **The 22 August rejection happened here, not in the code.** App Review
> Information was submitted **blank**. The reviewer therefore had no demo
> account, signed up for a free one, found the meditations locked behind a
> membership bought elsewhere, and applied Guideline 3.1.3(b) — the default
> rule — because nothing asked them to consider 3.1.3(a). Every line of the
> reader-app work was invisible to that review.
>
> **The copy below existing in this file is not the same as it reaching App
> Store Connect.** Paste it in, and check it is there on the submission
> screen before pressing send.


- [ ] Fill both `<FILL IN>` review accounts, and check they sign in on a
      device you are not already signed in on.
- [ ] **Paste the App Review Information → Notes block from Section 2 into App
      Store Connect**, with the demo account filled in. Blank notes is what
      caused the 22 August rejection.
- [ ] The demo account must be a **member with active access**, not an admin.
      An admin login hands a reviewer the dashboard; a member with no access
      shows them nothing but locked screens, which is what they reject on.
- [ ] Confirm the build you are attaching reports the version you expect.
      Apple reviewed "2.1.0 (24)" while `pubspec.yaml` had said 2.1.1 since
      before any of the reader-app work landed — a binary reporting the older
      version cannot contain it. Check the version and build number on the
      submission screen against the commit you meant to ship.
- [ ] Open the build and confirm the bottom tab reads **Videos**, not
      **Courses**. That single word is the fastest check that the binary
      carries the reframing rather than only the purchase removal.
- [ ] Give the review account an active membership, or the reviewer meets a
      paywall on the first paid screen and files it as a broken feature.
- [ ] Confirm all five policy URLs load **in a private window**. A normal tab
      carries your admin session and will show the page whether or not it is
      public — which is precisely how the last Play rejection was missed.
- [ ] Register the Play App Signing SHA-1 in Firebase, or Google Sign-In is
      broken for everyone who installs from the store.
- [ ] Fill the remaining CONFIRM values in `admin/src/lib/legal.ts` — the
      phone number and postal address are still placeholders, and they appear
      on the contact page a reviewer will open.
- [ ] **iOS only:** walk the build signed out and on a free account and
      confirm no price, no "Get Access", no "Register • ₹…" and no link to
      pay.anuragrishi.com appears anywhere. One survivor loses the reader-app
      exception and the rejection comes back. `kPurchaseUiEnabled` in
      `mobile_app/lib/core/config/purchase_config.dart` is the switch; the
      places it reaches are listed there.
- [ ] **iOS only:** check the scheduled pop-up's CTA label in the admin
      Settings page. It is free text stored in the database, so a label like
      "Register ₹499" would put a price on an iOS screen that no code change
      can catch.
