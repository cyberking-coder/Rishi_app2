# Design brief — Know Thyself mobile app

Paste everything below the line into Claude. It is written as a brief to
be answered, not a wish list: the constraints are real ones from the
shipped app, and a design that ignores them can't be built.

---

I need a premium visual redesign for **Know Thyself**, a meditation and
spiritual-learning mobile app by Anurag Rishi. Produce it as an
interactive HTML artifact showing the key screens as phone-sized frames I
can scroll through, with a design-token block I can hand to a Flutter
developer.

## What the app is

A meditation app that grew into a learning platform. People come to it to
sit quietly with guided audio, and they stay to work through structured
courses. Both halves matter and they pull in different directions — one
wants stillness and space, the other wants progress and structure. The
design's central problem is holding both without the app feeling like two
apps stitched together.

The audience is largely Indian, aged 25–55, on Android mid-range phones,
often in Hindi-English code-switching contexts. They are paying real money
(₹500–₹5000) for courses. It should feel like something worth having paid
for, and calm enough to open at 5am.

## The screens

Design these, in this order of importance:

1. **Home** — greeting by time of day, a featured daily practice, recently
   added audio, continue-listening row, category chips
2. **Course detail** — cover image, title and description, progress, a
   lesson list grouped into modules, price and buy button when locked
3. **Now playing** — full-screen audio player: artwork, scrubber, play
   controls, speed, sleep timer, download
4. **Courses catalog** — grid or list of courses, some locked, some in
   progress
5. **Profile** — name, membership status, enrolled courses with progress,
   settings
6. **Certificate** — the award screen after finishing a course

Secondary, if you have room: browse/search, downloads, video lesson,
text lesson, login.

## The current palette — keep it, refine it

This is already shipped and the brand sits on it. Improve it; don't
replace it.

```
background      #F2F2EF   warm off-white, never pure white
surface         #FFFFFF   cards
surfaceCream    #FBF7EC   secondary rows, warmer than surface
sage            #5F8D7E   primary brand and every primary action
sageDark        #44675C
sageLight       #8FB3A6
sageSoft        #E3EDE8   tinted pills, badges, icon chips
sand            #EFD9A8   warm accent, used sparingly
clay            #C97B5A   locked/premium and destructive states
textPrimary     #25332C
textSecondary   #7C8A83
border          #1425332C (8% of textPrimary)
radius          card 20 · row 16 · pill 999
```

If you think a colour is wrong, change it and say why in one line. Don't
change one silently.

## What "award-winning" has to mean here

Not decoration. Specifically:

- **Typographic hierarchy that survives long Hindi and Devanagari
  strings.** Course titles run long. Show me what a two-line title does
  to every card it appears in.
- **A real empty state and a real loading state for each screen.** Most
  designs skip these and they are half of what a new user actually sees.
- **A locked-content treatment that sells without nagging.** Free users
  see premium courses constantly. It must read as an invitation, not a
  paywall slammed shut.
- **Progress that means something.** Course progress, streaks and
  completion are the reason people come back. Make them legible at a
  glance without turning the app into a dashboard.
- **One idea carried everywhere.** Pick a single structural motif — a
  card shape, a rhythm of spacing, a way light falls — and hold it across
  every screen. Consistency reads as premium; variety reads as
  unfinished.

## Hard constraints — a design that breaks these can't ship

- **Flutter, Material 3.** No effects that need custom shaders, real
  blur-behind-content, or per-frame animation of large surfaces. Mid-range
  Android phones have to run this at 60fps.
- **Light theme is the product.** A dark theme exists but is secondary;
  design light first and show me one dark screen to prove the palette
  survives inversion.
- **Bottom navigation with four tabs**: Home, Courses, Downloads,
  Profile. It stays.
- **Content images are user-uploaded** and inconsistent — some portrait,
  some landscape, some low resolution, some with text baked in. Every
  image slot needs to look deliberate when the image is bad.
- **Text can be absent.** Descriptions, artist names and cover images are
  all optional in the database. Show what each card looks like with only
  a title.
- **No purchase button may say "buy", "subscribe" or "premium"** in the
  app itself. App Store rules push digital payment out to a web page; the
  in-app call to action is "Get Access Now" and tapping it opens a
  browser. Design that hand-off so it doesn't feel like an error.

## What to give me back

1. **The screens**, phone-width, in a scrollable artifact
2. **A token block** — exact hex values, spacing scale, radii, type
   ramp with sizes and weights — in a form a developer can transcribe
   directly into a Flutter theme
3. **Component specs** for the pieces that repeat: content card, lesson
   row, progress bar, locked badge, primary button, bottom nav
4. **A short rationale** — no more than a paragraph per screen — saying
   what decision you made and what you rejected

Don't show me mood boards or three alternative directions. Commit to one
and make it excellent.
