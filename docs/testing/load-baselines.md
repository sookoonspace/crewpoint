# Load baselines and cost estimate (Stage 1, #88)

Measured on 2026-11-11 on the Firebase emulators on a developer Mac, by
`functions/test_acceptance/load.test.ts` and
`functions/test/notifications/largePush.test.ts`. These are **emulator
baselines, not production promises** (Testing Strategy 5). Open Question 6
stays open: revisit these on a real device and a real project once
measured there.

## Fixture

`functions/test_acceptance/loadFixture.ts` generates the same data every run:
group sizes repeat 4, 3, 7, 1, 5, 2, 4, and the last group takes what is
left. 400 people make **108 groups**, matching the app's `scaleFamilies()`
in `test_acceptance/seed.dart`; 2,000 people make **539 groups**. Adults
and children, diets and kids-activity answers follow fixed formulas. The
event has two choice fields and twelve sessions over four days.

## Timings

| Step | 400 people | 2,000 people | Target (Req 60) |
|---|---|---|---|
| Import (CSV through `runImportJob`) | 0.53 s | 1.42 s | under 2 min at 400 |
| Roster page (51 by `sortName`) | 18 ms | 17 ms | under 1 s |
| Counts (`recalculateEvent`) | 48 ms | 137 ms | under 2 s at 2,000 |

Headcounts after the 400 import match the fixture: 400 people, 108 groups
(S-02).

## Large pushes (Req 61a)

`sendCategorizedPush` now reads recipients' preferences and event mutes
300 at a time with `getAll`, instead of two single reads per person. With
the transport mocked:

| Recipients | Before | After | Reads after |
|---|---|---|---|
| 2,000 | 9.6 s, 3,800 single reads | 0.26 s | 14 batched reads, 0 single |
| 5,000 | 21.7 s, 9,500 single reads | 0.41 s | 34 batched reads, 0 single |

Both fit the push triggers' 30-second limit. **5,000 holds** for the reads,
so no reading limit is recorded for Stage 3. What remains unmeasured is the
real FCM transport: 10 `sendEach` calls of 500 at 5,000 recipients. Stage
3's message queue should own sends beyond that, and measure delivery time
on a real project.

## Measured cost per operation

Counted documents read and written during the load test:

| Operation | Reads | Writes |
|---|---|---|
| Import, 400 people | 6 | 511 (people, groups, job) |
| Import, 2,000 people | 6 | 2,546 |
| Count run, 400 | 523 (event, fields, people, groups, sessions) | 1 |
| Count run, 2,000 | 2,554 | 1 |
| Roster page | 51 | 0 |
| Push to N people | 2N (preferences and mutes) | 0 |

A count run reads about 1.28 documents per person. Private choice fields
add one read per person.

## Monthly estimate (S-08)

### Assumptions

These are a busy registration month, not measured traffic.

- **Counts:** 30 runs a day, 900 a month. The 5-minute job also runs 8,640 times a month, with at least one read each.
- **Imports:** 4 a month.
- **Roster:** 1,500 page loads a month.
- **Whole-event pushes:** 60 a month.
- **Chat:** 1,500 messages a month. In the worst case, each message is read by every person, through the latest-50 listener.
- **App opens:** 30 per person a month, at about 20 reads each when the device's copy is cold.
- **Email and SMS:** none in Stage 1. They arrive in Stage 3.

### Prices

These are Firestore Standard edition list prices for a regional location.

| Item | Price | Free each month |
|---|---|---|
| Reads | $0.03 per 100,000 | 50,000 a day, about 1.5 M |
| Writes | $0.09 per 100,000 | 20,000 a day |
| Function calls | $0.40 per million | 2 million |

Multi-region `nam5` costs more and was not confirmed, so check
<https://cloud.google.com/firestore/pricing> before quoting. The upper
figure below assumes reads at $0.06 per 100,000.

| Tier | Reads a month | Writes a month | Function calls | Estimated cost a month |
|---|---|---|---|---|
| 400 | about 1.4 M | about 8,000 | about 15,000 | **$0**, within the free tier |
| 2,000 | about 6.8 M | about 18,000 | about 20,000 | **$1.60 to $3.20** (reads) |
| 5,000 (projected) | about 16.9 M | about 35,000 | about 30,000 | **$4.60 to $9.20** (reads) |

Chat readers and app opens make up most of the reads at every tier. Counts
come next. Writes and function calls stay inside the free tier at all
three tiers.

## Public event page speed (Spec #233 Req 69, #240)

**Measured Nov 25, 2026** on `crewpoint-dev.web.app/e/checks-2026` (a
published Convention event with a cover), Hosting from 56f349c, in Google
Chrome driven by `playwright-core` with the conditions below, a fresh
profile each run. **Content meets the budget; usable does not**, reported
to the owner (see Findings).

Budget: **content** (title, dates and place visible) within **4 s**, and
**usable** (Register can be tapped, and the first form field typed in)
within **6 s**.

Conditions: Chrome DevTools "Fast 4G" with 4x CPU slowdown, a first visit
with an empty cache, the release web build on `crewpoint-dev.web.app`, the
median of 5 runs. Then one check on a real mid-range Android phone over
mobile data. The server-rendered first page should meet the content budget
on its own; "usable" waits for the Flutter app and, for the first field,
for the registration form (#242).

Content is the server-rendered title and dates on screen (first contentful
paint). Register on that page is a plain link, tappable at the same moment,
but it loads the whole app; "App ready" is when the app shows the event and
removes the first page. The first field needs the form (#242).

| Run | Content (s) | Register tappable: first page / app ready (s) | First field typeable (s) |
| --- | --- | --- | --- |
| 1 | 0.88 | 0.88 / 20.8 | not yet (#242) |
| 2 | 0.67 | 0.67 / 13.3 | not yet |
| 3 | 0.66 | 0.66 / 13.3 | not yet |
| 4 | 0.57 | 0.57 / 13.4 | not yet |
| 5 | 0.44 | 0.44 / 13.6 | not yet |
| **Median** | **0.63** | **0.63 / 13.4** | not yet |
| Mid-range Android, mobile data | first page at once | **blank after the first page for over 2 minutes** | not yet |

### Findings (Nov 25, 2026)

- **Usable misses the 6 s budget**: the app downloads about 4.7 MB
  compressed (`main.dart.js` 1.5 MB, CanvasKit 1.5 MB, four Inter `.ttf`
  fonts 1.7 MB), so it is ready at about 13 s. Cheapest first remedies:
  `.woff2` fonts subset to the characters used, then deferred loading,
  then the WebAssembly build. Owner to decide.
- **The first page goes blank before the app is ready**: Flutter's canvas
  covers `#cp-ssr` as soon as the engine starts, so a slow phone sees the
  title and Register for a few seconds, then a blank screen until the app
  shows the event. Keeping `#cp-ssr` above the canvas until the hand-off
  removes it would fix that.
- **A real Android phone on mobile data stayed blank** for over 2 minutes
  after the first page (Chrome, Nov 25). Not yet diagnosed; needs the
  phone's console over USB.
- **App Check can lock a visitor out**: a browser that reCAPTCHA scores
  below dev's 0.5 gets 403, `getEventPage` refuses it (401), and the
  Firebase library waits a full day before trying again; the app shows
  "Couldn't load the event". Seen with automated Chrome; real visitors on
  VPNs or privacy browsers could score low too.
- **The cover was an 875 KB PNG** served as `cover.jpg`: a cover chosen
  on the web was not resized and re-encoded to JPEG.


A miss is reported to the owner, who decides the remedy; it is not
accepted silently.

Browsers to check (Req 70): iOS Safari 16+, Chrome on Android, and desktop
Chrome, Safari, Edge and Firefox.

| Browser | Page shows | Register works | QR code shows | Notes |
| --- | --- | --- | --- | --- |
| iOS Safari 16+ | | | | Not yet: waits on Xcode for iOS 27 |
| Chrome on Android | ❌ | | | Nov 25: blank after the first page (see Findings) |
| Desktop Chrome | ✅ | ✅ | ✅ | Nov 25: draft shows only "Not open yet"; signed in, Register opens the placeholder |
| Desktop Safari | ✅ | ✅ | ✅ | Nov 25: signed out, Register shows all four sign-in ways; Gujarati switches |
| Desktop Edge | | | | Not installed on the test Mac |
| Desktop Firefox | | | | Not yet |

