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
