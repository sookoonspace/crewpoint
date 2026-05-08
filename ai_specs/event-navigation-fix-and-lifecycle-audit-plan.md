## Overview

Fix "Event not found" via resolve-by-ID + `_EventGuard` (ref.listen-scheduled 750ms grace, hardened for timer-lifecycle test failures); bundle `_EventActions` `currentUserIdProvider` Consumer wrap. Append event lifecycle deep dive to V1 audit.

**Spec**: `ai_specs/event-navigation-fix-and-lifecycle-audit-spec.md` (commit `5917d9c`)

## Context

- **Structure**: feature-first under `lib/app/features/`; router at `lib/app/core/router/`.
- **State management**: Riverpod 3.
- **Reference implementations** (mirror exactly):
  - `lib/app/core/router/app_router.dart:155-162` — Consumer-uid threading pattern (used for `MemberManagementScreen` in PR #3 — same shape needed for `_EventActions`).
  - `lib/app/core/router/app_router.dart:280-354` — `_RouterErrorScreen` shape; mirror for `_EventNotFoundScreen` (icon, headline, body copy, primary button keyed `Key('event.notFound.back')`).
  - `test/app/core/router/app_router_test.dart:12-24` — `_wrapWithProviders` + `FakeAuthService` setup; reuse for every new router test.
  - `test/journeys/create_event_journey_test.dart` — extension target for the open-event journey.
- **Existing providers used (already shipped):** `dashboardEventsProvider`, `currentUserIdProvider` in `lib/app/core/providers.dart`.
- **Critical implementation rules from the spec:**
  - Timer scheduling lives in `ref.listen(... fireImmediately: true)` — NOT in `build()`.
  - `didUpdateWidget` MUST reset `_graceTimer` + `_graceElapsed` on `eventId` change.
  - `dispose` MUST cancel `_graceTimer` and null it out (otherwise tests hit "Timer still pending").
  - Tests pick exactly one timer pattern per scenario: A (`tester.pump(750ms)` + `pump()`), B (unmount before exit), or C (eventId switch). See spec `<validation>` for the explicit playbook.
- **Assumptions / Gaps:**
  - GoRouter inherits parent path params into nested route builders. Spec ships a `_resolveEventId(state)` helper with a `RegExp(r'/event/([^/]+)')` fallback against `state.matchedLocation` if the path-params route fails.
  - Riverpod 3 auto-cleans `Provider.family<EventModel?, String>` entries when no listeners remain.

## Plan

### Phase 1: Navigation by ID + `EventGuard` + uid wiring (vertical slice) ✅

- **Goal**: Tap any event tile → correct screen on iOS + web; reload-safe with brief grace spinner; no flicker; Leave/Delete buttons fire; test suite green with no pending-timer failures.

**Provider:**

- [x] `lib/app/core/providers.dart` — add `eventByIdProvider` (`Provider.family<EventModel?, String>`) reading `dashboardEventsProvider`'s `AsyncValue.maybeWhen(data: ...)`; returns matching event or null.
- [x] TDD: returns matching event from `data` emission.
- [x] TDD: returns null when id absent from `data` emission.
- [x] TDD: returns null while underlying provider is loading or in error.

**`EventNotFoundScreen` (lifted to `lib/app/core/widgets/event_guard.dart`):**

- [x] Public widget at `lib/app/core/widgets/event_guard.dart`. Constructor `EventNotFoundScreen({required String eventId})`. Logs eventId in `initState` via `developer.log(name: 'router')`. Layout mirrors `_RouterErrorScreen`: icon, headline, body, primary button keyed `Key('event.notFound.back')` calling `context.go('/dashboard')`. *Lifted from spec's "private to app_router.dart" guidance because Dart's library-private `_` prefix forbids `@visibleForTesting`; spec already authorized the lift.*

**`EventGuard` (also at `lib/app/core/widgets/event_guard.dart`):**

- [x] Public `ConsumerStatefulWidget`. Fields: `Timer? _graceTimer`, `bool _graceElapsed = false`. Methods: `_cancelGrace`, `_scheduleGrace` (no-op if timer in flight or grace elapsed).
- [x] `dispose` → cancel + null `_graceTimer`.
- [x] `didUpdateWidget` → on `eventId` change, cancel timer + reset `_graceElapsed = false` + schedule a post-frame re-evaluation.
- [x] `build`: empty `eventId` → `EventNotFoundScreen` immediately. Otherwise `ref.listen<AsyncValue<List<EventModel>>>(dashboardEventsProvider, _evaluate)` for transitions PLUS an `initState` post-frame `_evaluate(ref.read(...))` for the first emission (Riverpod 3's `WidgetRef.listen` deliberately omits `fireImmediately`, per its source comment). `build` reads `_graceElapsed` and renders progress / resolved / fallback.
- [x] TDD: shows progress while `dashboardEventsProvider` is loading. *(Pattern B)*
- [x] TDD: shows resolved screen when `eventByIdProvider(eventId)` returns the event. *(Pattern B)*
- [x] TDD: empty `eventId` → `EventNotFoundScreen` immediately, no grace. *(no Timer involved)*
- [x] TDD: shows progress (NOT fallback) for the first 750ms after `data: []` emission. *(Pattern B — unmount before grace fires)*
- [x] TDD: re-emission lands during grace → resolved screen renders, `_graceElapsed` clears if it had been set. *(Pattern B)*
- [x] TDD: 750ms elapses with event still missing → `EventNotFoundScreen`. *(Pattern A — `tester.pump(750ms)` + `pump()`)*
- [x] TDD: provider in `error` state → fallback renders, no grace. *(Pattern B)*
- [x] TDD: `didUpdateWidget` — eventId A in missing state past 750ms (Pattern A) → re-pump same instance with eventId B in resolved state → assert resolved screen renders without waiting another 750ms.
- [x] TDD: `dispose` cancels in-flight timer — pump with `data: []`, immediately unmount via `pumpWidget(SizedBox.shrink())` BEFORE 750ms; test exits with no "Timer still pending" failure. *(Contract test for the user-flagged failure mode.)*

**Route builder rewrites + `_resolveEventId` helper (6 sites):**

- [x] `app_router.dart` — added `String _resolveEventId(GoRouterState state)` helper: prefer `state.pathParameters['eventId']`; fall back to `RegExp(r'/event/([^/]+)').firstMatch(state.matchedLocation)?.group(1) ?? ''`.
- [x] Replaced `state.extra as EventModel?` reads at all 6 event routes (parent + members + budget + chat + tasks + task-detail) with `EventGuard(eventId: _resolveEventId(state), child: (event) => SubScreen(event: event))`. Dropped now-unused `EventModel` import.
- [x] TDD: parameterized router test (reuses `_wrapWithProviders` + `FakeAuthService`, extended to seed `dashboardEventsProvider`) — for each of the 6 URLs: resolved event renders the correct screen type; missing-id renders `EventNotFoundScreen` after grace; `Back to events` lands on `/dashboard`.

**Quick-link nav cleanup:**

- [x] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — dropped `extra: event` from the three `_QuickLinkCard` `onTap` handlers (Chat / Budget / Tasks).

**`_EventActions` uid wrap (bundled bug-prevention):**

- [x] `event_dashboard_screen.dart` — replaced bare `_EventActions(event: event, currentUserId: '')` with `Consumer(builder: (_, ref, _) => _EventActions(event: event, currentUserId: ref.watch(currentUserIdProvider) ?? ''))`.
- [x] TDD: with `currentUserIdProvider == event.creatorId` → owner-only Delete Event tile renders. With a non-creator uid → Leave Event tile renders, Delete hidden.
- [x] Pre-existing `event_dashboard_screen_layout_test.dart` updated to override `currentUserIdProvider` (the new Consumer wrap triggers the auth chain otherwise; same fix pattern as `dashboard_screen_layout_test.dart` from PR #3).

**Journey extension:**

- [x] Extended `test/journeys/create_event_journey_test.dart`: after the existing tile-appears assertion, tap the tile → assert `EventDashboardScreen` hero text matches AND no `event.notFound.back` button is present. Harness's mini-router extended with `/dashboard/event/:eventId` → `EventGuard(...)`.

**Verify:**

- [x] `flutter analyze` clean (only the pre-existing `TableMigration` experimental warning).
- [x] `flutter test` full suite green — 314 passed, 4 pre-existing skips. No "Timer still pending" failures.
- [ ] Manual smoke iOS sim: tap tile → see hero + quick links → tap each → return; tap Leave/Delete → action fires. *(User verification.)*
- [ ] Manual smoke web (`flutter run -d chrome --dart-define=FLAVOR=dev`): tap tile + reload at `/dashboard/event/{id}/budget` → spinner briefly → resolved screen. *(User verification.)*
- [ ] Manual smoke web direct URL `/dashboard/event/{nonexistent}` → spinner for 750ms → `EventNotFoundScreen`. *(User verification.)*

### Phase 2: Event lifecycle deep dive (audit doc)

- **Goal**: Append `## Event Lifecycle Deep Dive` section to `docs/v1-progress-audit.md`.

- [ ] `docs/v1-progress-audit.md` — append new section. 10-row matrix (*Step* / *Status* ✅⚠️❌ / *File refs* / *Follow-up*): create, view, edit, members, tasks, chat, budget, archive, leave, delete.
- [ ] Mark navigation + `currentUserId` rows as "Resolved in this PR" (Phase 1 of this plan).
- [ ] Cross-reference V1 audit Pillar 2 row at the top.
- [ ] Subsection: *Follow-up specs* — `event-archive-toggle-spec.md` (V1 should-ship), `event-edit-screen-spec.md` (V1.x). Note: uid-wiring follow-up is dropped (resolved here).
- [ ] `ai_specs/event-navigation-fix-and-lifecycle-audit-spec.md` — add a one-line link at the top pointing to the new audit section.
- [ ] Verify: every Status cell opens to a file; every Follow-up names a spec, "none", or "in this PR".

## Risks / Out of scope

**Risks:**

- **`ref.listen(fireImmediately: true)` semantics:** if Riverpod 3 calls the listener synchronously during build (rather than scheduling on a microtask), our listener body could trigger a `setState` during build via the timer's first `_scheduleGrace`. The sketch avoids this by only setting a `Timer` (which fires async). If implementation deviates, watch for "setState called during build" errors.
- **GoRouter parent path-param inheritance:** assumed via `state.pathParameters['eventId']`. The `_resolveEventId` `matchedLocation` regex fallback covers the case where the assumption fails — keep it even if the param works.
- **Riverpod 3 family cleanup:** `eventByIdProvider(id)` accumulates entries as users open events. Acceptable for V1; revisit if profiling shows a leak.

**Out of scope:**

- Edit-event screen — V1.x follow-up spec.
- Archive toggle Firestore wiring — V1 should-ship, separate spec.
- Sub-screen widget internals (chat / budget / tasks / members) — they accept `event:` and remain unchanged.
- Firestore web offline persistence — separate V1 audit launch blocker.
- One-shot Firestore `doc(id).get()` for cross-account deep links — grace + dashboard list is sufficient for V1.
- Lifting `_EventGuard` to `lib/app/core/widgets/` — keep private until reused outside the router.
