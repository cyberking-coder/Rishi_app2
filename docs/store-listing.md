# Store listing copy — Know Thyself 2.1.0

Everything the two stores ask for, in the order they ask for it. Replaces
the 1.x `play-store-listing.md`, which still described a dark-violet
interface, an audio-only app and deletion by email — none of which are
true any more.

Character limits are the stores' own. Where a field is at its limit it is
marked, so an edit does not silently overflow and get truncated mid-word.

- **iOS bundle ID:** `com.anuragrishi.knowthyself`
- **Android package:** `com.knowthyself.app`
- **Version:** 2.1.0 (build 13)

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
New: ask the guide anything, in English, Hindi or Marathi — by voice or by typing. Plus guided courses, live sessions with Anurag Rishi, and offline listening.
```

### Description (4000 max)
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

COURSES, ONE LESSON AT A TIME

Structured programmes that build. Each lesson unlocks as you go, your place is
remembered, and finished courses issue a certificate you can keep and share.
Course materials — worksheets, readings, audio — come attached to the lessons
they belong to.

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
second. Your progress, your downloads and your place in every course follow
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
```
• Ask the guide — a companion that knows the library and your progress. Type or
  tap the microphone and speak, in English, Hindi or Marathi.
• A completely new look: softer, quieter, easier to read.
• Live sessions you can register for and join from inside the app.
• Sign in with Apple.
• Delete your account and all your data from Profile → Settings, at any time.
• Fixes to playback, downloads and notifications.
```

### App Review Information → Notes
```
DEMO ACCOUNT
The account below is signed in and has an active membership, so every
screen — including paid courses and live sessions — is reachable without
making a purchase.

  Email:    <FILL IN>
  Password: <FILL IN>

ONE-DEVICE SIGN-IN
The app allows one device per account at a time, as a licence-sharing
control. If the demo account was signed in elsewhere it will sign that
session out rather than refuse yours; if you hit any device error, sign in
again and it will clear.

HOW TO REACH EACH FEATURE
  • Ask the guide — Home tab, the "Ask the guide" row under the search bar.
    The microphone is at the right of the message box. It needs the
    microphone permission and a network connection.
  • Courses — Courses tab. The demo account has access to all of them.
  • Live sessions — Home tab, "Live sessions".
  • Account deletion — Profile tab → Settings → Delete account. This deletes
    the account immediately and cannot be undone, so please use a throwaway
    signup rather than the demo account above if you want to test it.

PAYMENTS
Courses and seats at live sessions are sold through an external web page at
pay.anuragrishi.com, opened in the device browser. Payment is handled by
Razorpay, an Indian payment gateway, in Indian rupees. There is no purchase
flow inside the app itself.

MICROPHONE
Requested only when the user taps the microphone in the guide, for dictation.
Speech recognition runs on the device through the system recogniser; no audio
is recorded to a file or transmitted by the app.
```

### Sign in with Apple
Required, and implemented — the app offers Google Sign-In, which triggers
Guideline 4.8. Confirm before submitting that the capability is enabled on
the App ID in the Developer portal, or the button fails at runtime with an
opaque authorisation error.

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

- [ ] Fill both `<FILL IN>` review accounts, and check they sign in on a
      device you are not already signed in on.
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
