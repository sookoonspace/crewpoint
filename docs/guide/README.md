# CrewPoint v1 — Scenario Testing Guides

Three tutorial-style, multi-persona walkthroughs that stress CrewPoint v1 against realistic use cases — built to surface where v1 falls short **before** strangers do. These guides complement, not replace, the feature-by-feature checklist at [`../qa/v1-tester-handoff-guide.md`](../qa/v1-tester-handoff-guide.md).

## When to use which

| If you want to test... | Use... |
|---|---|
| Every individual feature (auth, profile, tasks, chat, budget) one at a time | [`../qa/v1-tester-handoff-guide.md`](../qa/v1-tester-handoff-guide.md) |
| How the app holds together for a real organizer end-to-end | This folder |
| Push-notification setup specifically | [`../qa/push-notifications-testing-guide.md`](../qa/push-notifications-testing-guide.md) |

## The three scenarios

1. [`01-cricket-tournament.md`](./01-cricket-tournament.md) — **Mumbai Sixers Invitational**, 4 teams × 5 active, INR.
2. `02-hotel-convention.md` — **Aurora Hospitality Annual Summit**, 25 attendees, USD. *(Phase 2.)*
3. `03-wedding-event.md` — **Priya & Marcus, 2026-10-17**, 30 guests, INR. *(Phase 2.)*

Run them in any order. Each is independent and contains a Build-info / Prerequisites block; later guides cross-link to earlier ones for primitive flows.

---

## Bug vs gap — read this before filing anything

> A **bug** is when the app crashes, throws a red error, freezes, or fails to do something it explicitly promises (e.g., a button that does nothing, a tap that loses data, a snackbar that says "Failed to..." when there's no network problem). Use the bug-report template in [`../qa/v1-tester-handoff-guide.md` §14](../qa/v1-tester-handoff-guide.md#14-bug-report-template).
>
> A **gap** is when the app works perfectly but you wish it had a tool to finish your scenario (e.g., "I wish I could see all matches on a calendar grid", "I wish I could collect RSVPs", "I wish I could mute notifications between 10 pm and 8 am"). Log gaps in [`./GAPS.md`](./GAPS.md) — do **NOT** file them as bugs.

If you're unsure: ask yourself "did the app *try and fail*, or did it *not even attempt*?" Try-and-fail = bug. Not-attempted = gap.

---

## You only operate the active personas (don't burn out)

Each scenario lists **3–4 active personas** (real test accounts that real testers sign into) and **N abstract personas** (the other 19 players, the other 26 guests). Abstract personas are **names in the narrative only** — you do NOT create accounts for them. When a scenario says "CapA invites the rest of Team A", the tester verifies the invite mechanism works **once**, then moves on. Do NOT create 19 dummy accounts. Do NOT create 26 guest accounts.

This rule is repeated as a banner at the top of every scenario file. Honor it — the guides are designed around it.

---

## Persona × device matrix

| Scenario | Active personas | Devices ideally | Min devices | Est. tester-hours |
|---|---|---|:---:|:---:|
| Cricket | `TD` Tournament Director (owner), `CapA` Team Captain A (admin), `PlayerA1` Player on Team A (member), `SponsorS` Sponsor Rep (member, view-only role-play) | iPhone + Android + Web Chrome | 2 | ~5 |
| Convention | `CL` Convention Lead (owner), `SC` Speaker Coordinator (admin), `Spkr` Speaker (member), `SponLi` Sponsor Liaison (member) | iPhone + Android + iPad/tablet | 2 | ~6 |
| Wedding | `Couple` Bride+Groom (owner — shared single account), `WP` Wedding Planner (admin), `FL` Family Lead — bride's side (member), `Vend` Anita — Catering Vendor (member) | iPhone + Android | 2 | ~5 |

**Ideal minimum:** 2 testers × 2 devices (iPhone + Android) per scenario. **Preferred:** 3 testers × 3 devices for cricket + convention (the multi-faction scenarios). Web parity sections cover Chrome + Safari at the end of each guide.

A single tester can run a scenario solo by baton-passing between accounts; the guide marks where coverage is lost.

---

## Build info — fill before handing to testers

| Item | Value |
|---|---|
| iOS build (TestFlight) | `<insert TestFlight invite link>` |
| Android build (internal track) | `<insert Google Play internal track link>` |
| Web app (staging) | `<insert Web Firebase Hosting URL>` |
| Staging Firebase project | `<ask the dev team>` |
| Test-account credentials | `<dev team supplies a private channel — 4 active accounts per scenario, with Venmo + Cash App handles set for at least 2 of them>` |

### Pre-flight V1-launch-blocker verification (founder, performed 2026-06-12)

| Blocker | Status on `main` | Scenario impact |
|---|---|---|
| `CreateTaskScreen` silent-no-op (audit blocker #3) | ✅ Resolved — `event_tasks_page.dart:40-49` wires `onSubmit` → `taskRepositoryProvider.createTask`. | Cricket Ramp-up (8+ task creations) is buildable as-is. |
| `EditEventScreen` missing (audit row 4) | ✅ Resolved — `app_router.dart:178` routes to `_EditEventRouteScreen` → `eventRepositoryProvider.updateEvent`. | Wrap-up edit steps are standard, not gap-callouts. |
| Archive Event UI-only (audit row 10) | ✅ Resolved — `event_dashboard_screen.dart:606-639` persists via `eventRepositoryProvider.updateEvent`. | Wrap-up archive steps are standard, not gap-callouts. |
| `JoinEventSheet` callback wiring (audit blocker #4) | ✅ Resolved — calls `FirebaseFunctions.instance.httpsCallable('joinEvent')` directly; no callback indirection. | Convention join flow is buildable. |

Re-verify on the build under test before each scenario run. If status regresses, the matching scenario step becomes a gap-candidate callout (see §"What to do if…" in each guide).

---

## Known web / infra constraints — NOT bugs

Testers MUST know these before working on web or testing notifications. **Do not file these as bugs.**

1. **Web OAuth uses popup, not native sheet.** Firebase web SDK constraint (`signInWithPopup`). If your browser blocks the popup, follow `AUTH-WEB-01` in the handoff guide to recover.
2. **Web caches reads in IndexedDB, but only in one tab at a time.** Firestore web persistence was turned ON 2026-08-08 (closes audit V1 launch blocker #6), so a reload now renders from the local cache before the network responds. Two caveats testers will hit: (a) **only the first open tab gets the cache** — the plugin offers no multi-tab option, so a second tab on the same browser runs uncached and will feel slower on reload. That is expected, not a bug. (b) Cached *reads* are not queued *writes* — see constraint 3.
3. **The UI still gives you no offline-write affordance (mobile or web).** The Firestore SDK now holds a local write queue on every platform, but the app awaits each write's server acknowledgement, so submitting with no network leaves you on a spinner rather than a confirmation — there is no "saved, will sync" state, no retry button. Treat submissions as requiring a network. *If a queued write does land on its own after you reconnect, note it in your debrief — that path has not been verified on a device.*
4. **No FCM web push delivered to users yet.** Phase 6.2 schema landed (platform-tagged token storage), user-facing delivery deferred. Chrome and Safari testers will receive **zero** push notifications — this is expected.
5. **Zelle / PayPal / Cash / Other settle paths fall through to the manual fallback sheet** (`LED-FALL-01` "Copy payment details" + handle). No deep link — Pillar 3 design decision pending. Testing a Zelle settle and getting the fallback sheet is the correct v1 behavior.
6. **Profile → Notifications row is a deliberate no-op.** Tapping it does nothing on purpose (`PROF-NOTIF-01` "Notifications row is a deliberate no-op (NOT a bug)"). The per-category preferences UI is the headline notifications gap, logged as `GAP-ANY-25` — confirm the no-op, do not file a bug.

(Stale-label rule: if a literal **bolded label** in any scenario doesn't match the live app, file a guide-bug — note it in a comment on `01-cricket-tournament.md` etc. — not an app-bug.)

---

## Tester debrief — fill at the end of each scenario

Three questions, two paragraphs max. The founder reads every one.

1. **What gap surprised you most?** (Something you assumed v1 would do, that it didn't.)
2. **Which phase felt the longest?** (Where did the air go out of the scenario?)
3. **Would you ship v1 today?** Yes / No — and one sentence on why.

Paste responses into the same channel as the test-account credentials.

---

## How to read the per-step format

Every step in a scenario follows the same shape:

- Persona swim-lane callout in bold brackets: `**[CapA — iPhone]**` tells you who acts on which device.
- **Literal labels** (bold) — verbatim text on the screen. If the live app shows a different word, that's a stale-label issue (see above).
- *User input* (italics) — what to type.
- Expected outcome — listed as a sub-bullet. No "should" or "may" — these are absolutes.
- `> 🕳️ **Gap candidate:** …` — pre-seeded callout pointing to a `GAP-XXX-NN` entry in [`./GAPS.md`](./GAPS.md). Confirm whether your tester experience matches; update the entry's Workaround line if you find a better one.

Every scenario ends with a **§Forced-fail drills** section (3–5 tight recipes designed to break things on purpose) and a **§Web parity** mini-section (which phases to re-run on Chrome / Safari and what to skip).
