<goal>
Two deliverables in one spec:

1. A grounded audit of V1 progress against the five-pillar goal set (offline-first foundation, unified event hub, zero-liability settlements, professional web parity, minimum-viable-data security), captured as an inline status matrix the team can act on.
2. A targeted fix for the Create Event button, which today silently no-ops because the router renders `const CreateEventScreen()` without an `onSubmit` handler — no error surfaces, nothing persists, and the user is left wondering whether the tap registered.

The audit becomes the V1 punch list that sequences the remaining work. The fix unblocks the dashboard's primary call-to-action so early consumer adopters can actually create events and exercise the rest of the app.
</goal>

<background>
**Tech stack:** Flutter 3.11.5 / Dart 3.x, Riverpod 3, GoRouter 14, Firebase (Auth, Firestore, Storage, Functions, Messaging), Drift 2.25 SQLite (mobile/desktop only), pdf/printing/csv for exports.

**V1 architectural intent — Firestore-Write / Drift-Read:**

- All writes go to Firestore. The Firestore SDK's native offline persistence handles write-queuing while offline and replays on reconnect — we do NOT build a custom outbox or sync engine.
- Each repository starts a Firestore query listener on the user's data and mirrors snapshots into Drift on mobile/desktop. The UI reads from Drift, which gives fast, un-evicted local access (Firestore's local cache is bounded and LRU-evicts under pressure).
- Membership lifecycle (`joinEvent`, `promoteToAdmin`, `demoteAdmin`, `removeEventMember`, `generateInviteCode`) stays in Cloud Functions. Clients never mutate `memberIds` / `adminIds` / `creatorId` directly — `firestore.rules:22-33` enforces this with field-level guards.
- This is the pattern already used by `taskRepositoryProvider` and `expenseRepositoryProvider` in `lib/app/core/providers.dart` — both documented as *"Firestore source of truth + Drift mirror"*. Events MUST follow the same pattern.
- On web there is no Drift persistence (Wasm is in-memory; `providers.dart:76-79` calls this out). Web reads directly from the Firestore stream; the Drift mirror is a no-op or skipped on web.
- `lib/app/core/services/sync_engine.dart` and `lib/app/core/services/i_sync_service.dart` are dead/aspirational code: registered in no provider, called from nowhere, and architecturally superseded by the per-repository pattern. The audit MUST recommend deleting them.

**Bug evidence — Create Event silently no-ops:**

- `lib/app/features/dashboard/presentation/create_event_screen.dart:64-82` — `_submit()` validates the form, builds an `EventModel`, then calls `widget.onSubmit?.call(event)`. The `?.` short-circuits when `onSubmit` is null.
- `lib/app/core/router/app_router.dart:135` — `builder: (_, _) => const CreateEventScreen()` — the router instantiates the screen with no callback, so `onSubmit` is always null in production.
- `creatorId` is hard-coded to `''` (line 74); `adminIds` / `memberIds` default to `const []`.
- The current `EventRepository` (`lib/app/features/dashboard/data/event_repository.dart`) is Drift-only with no Firestore wiring at all — the odd one out vs. tasks/expenses/chat. Stage 2 rewrites it to match the Firestore-Write / Drift-Read pattern.
- `DashboardScreen` (`dashboard_screen.dart:19`) is a hardcoded empty list with `// TODO: Wire to event provider...`. Even if create persisted correctly today, the dashboard would never re-render.
- No `eventRepositoryProvider` / `dashboardEventsProvider` / `currentUserIdProvider` is registered in `lib/app/core/providers.dart` — all three must be added.
- `app_router.dart:158` passes `currentUserId: ''` to `MemberManagementScreen` — same root cause, different screen. Stage 2 fixes this in the same pass.

**Files to examine for the fix:**

- `@lib/app/features/dashboard/presentation/create_event_screen.dart`
- `@lib/app/features/dashboard/presentation/dashboard_screen.dart`
- `@lib/app/core/router/app_router.dart`
- `@lib/app/features/dashboard/data/event_repository.dart` (full rewrite)
- `@lib/app/features/dashboard/application/dashboard_provider.dart` (delete — replaced by `dashboardEventsProvider`)
- `@lib/app/core/database/daos/events_dao.dart`
- `@lib/app/core/database/app_database.dart` (drop the FK on `Events.creatorId`; bump `schemaVersion`)
- `@lib/app/features/auth/application/auth_provider.dart`
- `@lib/app/features/dashboard/domain/models/event.dart`
- `@lib/app/core/providers.dart` (register `eventRepositoryProvider`, `dashboardEventsProvider`, `currentUserIdProvider`)

**Reference implementations to mirror (do not invent a new pattern):**

- `@lib/app/features/tasks/data/task_repository.dart` — Firestore listener + Drift mirror lifecycle (`disposeMirror`, `watchTasksByEventId`).
- `@lib/app/features/budget/data/expense_repository.dart` — same pattern with image-service dep injection.
- `@lib/app/core/providers.dart:108-127` — how `taskRepositoryProvider` and `taskListProvider` are wired.

**Files to examine for the audit (per pillar):**

- *Offline-first:* `@lib/app/core/database/`, `@lib/app/core/providers.dart` (Firestore offline persistence enablement), and confirmation that `@lib/app/core/services/sync_engine.dart` + `@lib/app/core/services/i_sync_service.dart` are removed.
- *Event hub:* `@lib/app/features/tasks/`, `@lib/app/features/chat/`, `@lib/app/features/budget/`, `@functions/src/events/onUrgentMessageCreated.ts`.
- *Settlements:* `@lib/app/features/budget/data/pay_link_builder.dart`, `@lib/app/features/budget/presentation/widgets/settle_sheet.dart`, `@lib/app/features/budget/data/expense_repository.dart`, `@lib/app/core/services/firebase_image_service.dart`, `@lib/app/features/budget/domain/models/balance_ledger.dart`.
- *Web parity:* `@lib/app/core/widgets/responsive_shell.dart`, `@lib/app/core/widgets/content_max_width.dart`, `@lib/app/features/budget/data/expense_pdf_builder.dart`, `@lib/app/features/budget/data/expense_csv_builder.dart`, `@lib/app/features/tasks/data/task_pdf_builder.dart`.
- *MVD security:* `@lib/app/features/auth/application/auth_provider.dart`, `@lib/app/features/profile/data/firestore_user_repository.dart`, `@functions/src/account/deleteUserAccount.ts`, `@firestore.rules`.
</background>

<user_flows>
**Create Event — primary flow (after fix):**
1. Authenticated user taps Create Event from the dashboard.
2. Form opens; user enters title (required), optionally description, type, start date, currency.
3. User taps Create Event.
4. Form validates; the button shows a loading indicator and is disabled.
5. Event persists to Drift; creator becomes sole admin + member; status = active.
6. Screen pops back to dashboard; a SnackBar confirms creation; the new event appears as a tile in the list.

**Alternative flow — invalid form:**
- Empty title or >200-char title → inline validator message; no persistence; button stays enabled.

**Error flows:**
- Firestore write throws (rules denial, quota, transient SDK error) → repository surfaces the exception → screen stays open, inline error banner appears, no navigation pop, user can retry. Note: transient *offline* writes are queued by Firestore SDK persistence and don't surface as errors.
- User is signed out at submit time → submit aborts before any write; "Sign-in required" error is shown. *Defensive only — `app_router.dart:85-89` already redirects unauthenticated users away from `/dashboard/create`.*
- User taps Create Event twice rapidly → second tap is a no-op because the button is disabled while the future is pending.
</user_flows>

<requirements>
**Functional — V1 Audit (Stage 1):**

1. Produce a status matrix in `docs/v1-progress-audit.md` covering each of the five pillars with columns: *Pillar*, *V1 Intent (one line)*, *Done (file refs)*, *Missing/Stubbed (file refs or "no such file")*, *Severity* (must-ship / should-ship / nice-to-have for V1). Link from this spec.
2. Every "done" claim MUST cite a concrete file path or function name; every "missing" claim MUST cite a file or include a search proof showing the absence.
3. The audit MUST recommend deleting `lib/app/core/services/sync_engine.dart` and `lib/app/core/services/i_sync_service.dart`. They are dead code — registered in no provider, called from nowhere, and architecturally superseded by the per-repository Firestore-Write / Drift-Read pattern.
4. The audit MUST verify that Firestore offline persistence is enabled for the Flutter SDK (this is the offline-first mechanism for writes; without it, the architecture's offline pillar collapses).
5. The audit MUST verify and report status for at minimum:
   - Drift schema coverage of all V1 entities (events, tasks, expenses, expense_splits, chat_messages, users, task_checklist_items).
   - Greedy settlement algorithm — locate it (likely `balance_ledger.dart`) and confirm correctness via existing tests.
   - Urgent-message FCM path — verify `functions/src/events/onUrgentMessageCreated.ts` exists, is deployed, and is invoked from the chat write path.
   - Pay-link deep links — verify `pay_link_builder` covers Venmo, CashApp, and Zelle (or document which are missing).
   - Receipt upload + silent compression — verify the path through `image_picker` → `firebase_image_service` → Storage.
   - Web responsive shell + ContentMaxWidth clamping.
   - CSV + PDF exports for tasks and expenses.
   - Account deletion Cloud Function — verify it wipes solitary events, anonymizes shared records to `deleted_user`, and deletes the Auth user.
   - Auto user-doc creation on every authenticated `AuthNotifier` emission.
6. The audit MUST end with two short lists: *V1 launch blockers* and *V1.x follow-ups*. The Create Event no-op is a launch blocker by definition. The same silent-no-op pattern in `CreateTaskScreen` (`create_task_screen.dart:73`) and `JoinEventSheet` MUST be listed as launch blockers if they remain unfixed at audit time.

**Functional — Create Event Fix (Stage 2):**

7. Tapping Create Event on a valid form writes exactly one event document to Firestore at `events/{eventId}` via a rewritten `EventRepository.createEvent`.
8. The persisted document has `creatorId = currentUser.uid`, `adminIds = [uid]`, `memberIds = [uid]`, `status = 'active'`, `createdAt` / `updatedAt` server timestamps, and the form-supplied `title`, `description`, `eventType`, `startDate`, `currency`. This satisfies `firestore.rules:18-19` (create requires `creatorId == auth.uid`) and `:14-15` (read requires uid in `memberIds`).
9. The new `EventRepository` follows the same shape as `TaskRepository` / `ExpenseRepository`:
   - Writes go to Firestore directly; Firestore offline persistence handles queuing on the device.
   - A Firestore query listener (`events.where('memberIds', arrayContains: uid)`) mirrors snapshots into Drift on mobile/desktop.
   - `watchEventsForUser(String uid)` returns a `Stream<List<EventModel>>`; on mobile/desktop the stream is Drift-backed and the listener fills it; on web the stream is the raw Firestore snapshot stream.
   - `dispose()` / `disposeMirror()` lifecycle matches the existing repos.
10. New providers in `lib/app/core/providers.dart`:
    - `currentUserIdProvider` — `Provider<String?>` derived from `authProvider`: returns `state.user.uid` when state is `Authenticated`, else `null`.
    - `eventRepositoryProvider` — constructs `EventRepository` with `EventsDao(databaseProvider)` and `firestoreProvider`; disposes on shutdown.
    - `dashboardEventsProvider` — `StreamProvider<List<EventModel>>` that reads `currentUserIdProvider` and calls `eventRepositoryProvider.watchEventsForUser(uid)`. Emits an empty list when uid is null.
11. `DashboardScreen` is rewired to consume `dashboardEventsProvider` and renders the live event list via `AsyncValue.when(...)`. The hardcoded `final events = <EventModel>[];` at `dashboard_screen.dart:19` is removed. The existing `_EmptyState` is shown when the stream emits an empty list.
12. On success, `CreateEventScreen` pops to the dashboard and a SnackBar confirms creation. The `ScaffoldMessenger` MUST be captured **before** the await/pop (see `<implementation>`) — calling `ScaffoldMessenger.of(context)` after pop throws.
13. On failure (Firestore write throws or repository surfaces an error), the screen stays open, surfaces a visible error message ("Couldn't create event — try again"), and does NOT show a success SnackBar.
14. While the write is in flight, the Create Event button shows a progress indicator and is disabled to prevent double-submit.
15. If `currentUserIdProvider` is null at submit time (defensive — router redirect prevents this in practice), the screen shows a "Sign-in required" error and does not call the repository.
16. Drop the foreign-key constraint on `Events.creatorId → Users` in `lib/app/core/database/app_database.dart:29` (change `text().references(Users, #id)()` → `text()()`). Bump `schemaVersion` from 4 → 5; add a migration step. Rationale: the auth flow only writes to Firestore via `FirestoreUserRepository`; it does not materialise a Drift `Users` row. Tasks and Expenses don't depend on Drift `Users` either — events should match.
17. `app_router.dart:158` is updated: replace the `currentUserId: ''` placeholder with a `Consumer` builder that reads `currentUserIdProvider` and threads the uid into `MemberManagementScreen` (or convert the screen to read it directly).
18. Delete `lib/app/features/dashboard/application/dashboard_provider.dart` — `DashboardNotifier` is replaced by `dashboardEventsProvider`.

**Out of scope for Stage 2 — listed in audit as launch blockers if unfixed:**

19. `CreateTaskScreen` (`create_task_screen.dart:73`) has the identical silent-no-op `widget.onSubmit?.call(task)` pattern. Its fix is a separate spec.
20. `JoinEventSheet` and any other form-and-callback widgets where the production caller doesn't supply a handler.

**Error Handling:**

21. Repository-level exceptions are logged via `dart:developer log` (existing convention in `EventRepository`) and MUST surface to the UI — never swallowed silently.
22. The `onSubmit` test seam in `CreateEventScreen` is removed. No current test depends on it (no `create_event_screen_test.dart` exists).

**Edge Cases:**

23. Title-only submit (no description, no startDate) succeeds.
24. Existing length cap (>200 chars) remains blocked by the form validator.
25. Tapping Create Event twice rapidly results in only one Firestore write (button disabled during in-flight future).
26. Offline submit — Firestore SDK queues the write; the local Firestore cache reflects the pending mutation; the listener-driven Drift mirror updates locally; the dashboard tile appears immediately. The write replays automatically on reconnect.
27. UUID collision (vanishingly rare) surfaces as a failure, not silent success.

**Validation (input):**

28. Existing form validators (title required, ≤200 chars) remain authoritative.
29. Currency must be one of `CreateEventScreen.supportedCurrencies`.
</requirements>

<boundaries>
**Edge cases:**
- Drift mirror failure (disk full, mirror disposed mid-flight) → on web the UI keeps reading from the Firestore stream; on mobile, the listener retries via Firestore SDK reconnection. User-visible behaviour is unchanged in the steady state.
- User signs out between form open and submit → submit aborts, "Sign-in required" error shown (defensive — router already prevents this path).
- Network offline at submit → Firestore SDK queues the write locally and replays on reconnect. The local Firestore cache + listener-driven Drift mirror means the new tile appears on the dashboard immediately.

**Error scenarios:**
- Firestore rules denial (e.g., uid mismatch on `creatorId`) → repository surfaces the `FirebaseException` → inline error widget visible.
- Firestore quota / permission error → same path; user can retry.
- Drift FK constraint violation → impossible after the FK is dropped (req #16). Listed only because the current code has this trap waiting.
- Firestore offline persistence disabled → writes throw immediately when offline. Audit MUST verify persistence is enabled.

**Limits:**
- Cross-device parity: delivered by the Firestore listener. New events appear on the creator's device immediately and on co-members within seconds when online; offline devices catch up on reconnect via Firestore offline persistence.
- Web Drift mirror: skipped (Wasm is in-memory; `providers.dart:76-79`). Web reads from the Firestore stream directly. The audit MUST flag this if any V1 feature relies on the Drift cache for cold-start UX on web.
- Custom sync engine: explicitly NOT building one. Firestore offline persistence is the queuing layer. Anyone tempted to revive `sync_engine.dart` should re-read this section first.
</boundaries>

<implementation>
**Stage 1 — V1 Progress Audit**

Produce the matrix as `docs/v1-progress-audit.md`. For each of the five pillars:

- *Done:* list files/functions present and the tests proving them.
- *Missing/stubbed:* list concrete gaps with file refs or absence proofs.
- *Severity:* must-ship / should-ship / nice-to-have for V1.

End the audit with:

- *V1 launch blockers* (must close before crewpoint.sookoon.space goes public).
- *V1.x follow-ups* (post-launch, before paid plans).

**Stage 2 — Create Event Fix (Firestore-Write / Drift-Read)**

*Files to rewrite or add:*

- **`lib/app/features/dashboard/data/event_repository.dart` — full rewrite.** Mirror `TaskRepository`'s shape:
  - Constructor takes `EventsDao` and `FirebaseFirestore` (no longer accepts only the DAO).
  - `Future<void> createEvent(EventModel event)` writes to `firestore.collection('events').doc(event.id).set({...})` with `creatorId`, `adminIds`, `memberIds`, `status: 'active'`, `createdAt`/`updatedAt: FieldValue.serverTimestamp()`, and the form-supplied fields. Throws on failure (do not swallow).
  - `Stream<List<EventModel>> watchEventsForUser(String uid)` — starts/reuses a Firestore listener via `_ensureMirror(uid)`; on mobile/desktop returns `_eventsDao.watchAllEvents().map(_toDomain)`; on web returns the raw Firestore snapshot stream.
  - `_ensureMirror(String uid)` opens a Firestore subscription on `events.where('memberIds', arrayContains: uid)` and on each snapshot upserts into Drift via the DAO. Re-entrant; idempotent.
  - `disposeMirror(String uid)` and `dispose()` lifecycle as in `TaskRepository`.
  - Provide a thin mapper `EventModel _toDomain(DocumentSnapshot)` and a Drift-row → domain mapper. Tested independently.

- **`lib/app/core/providers.dart` — register three new providers** (place near `taskRepositoryProvider`):
  - `currentUserIdProvider` — `Provider<String?>` derived from `authProvider`. When state is `Authenticated`, return `state.user.uid`; else null.
  - `eventRepositoryProvider` — `Provider<EventRepository>` constructing the repo with `EventsDao(ref.watch(databaseProvider))` and `ref.watch(firestoreProvider)`; `ref.onDispose(repo.dispose)`.
  - `dashboardEventsProvider` — `StreamProvider<List<EventModel>>` that reads `currentUserIdProvider`; if uid is null emits `Stream.value(<EventModel>[])`; else returns `ref.watch(eventRepositoryProvider).watchEventsForUser(uid)` and `ref.onDispose(() => repo.disposeMirror(uid))`.

- **`lib/app/features/dashboard/presentation/dashboard_screen.dart` — wire up data.** The screen is already a `ConsumerWidget`; replace `final events = <EventModel>[];` with `final eventsAsync = ref.watch(dashboardEventsProvider);` and render `eventsAsync.when(data: ..., loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => _ErrorState(error: e))`. Empty data path still renders `_EmptyState`. Add `Key('dashboard.events.list')` to the rendered `ListView.separated`.

- **`lib/app/features/dashboard/presentation/create_event_screen.dart`:**
  - Convert from `StatefulWidget` to `ConsumerStatefulWidget`. `const CreateEventScreen()` continues to work — `const` is supported on ConsumerStatefulWidget.
  - Remove the `onSubmit` parameter. No tests depend on it.
  - In `_submit()`:
    1. Validate the form; return early if invalid.
    2. Capture `final messenger = ScaffoldMessenger.of(context);` BEFORE the await — calling `ScaffoldMessenger.of(context)` after `Navigator.pop` throws.
    3. Read `final uid = ref.read(currentUserIdProvider);`. If null, set an error message and return.
    4. `setState(() => _isSubmitting = true);`
    5. Build `EventModel(id: uuid, creatorId: uid, adminIds: [uid], memberIds: [uid], status: EventStatus.active, ...)`.
    6. `try { await ref.read(eventRepositoryProvider).createEvent(event); if (mounted) Navigator.pop(context); messenger.showSnackBar(SnackBar(content: Text('Event created'))); } catch (e, st) { log(...); if (mounted) setState(() { _isSubmitting = false; _error = "Couldn't create event — try again"; }); }`.
  - Add stable keys: `Key('createEvent.submit')` on the button, `Key('createEvent.error')` on the inline error widget.

- **`lib/app/core/router/app_router.dart`:**
  - Line 135: keep `(_, _) => const CreateEventScreen()`.
  - Line 158: replace `currentUserId: ''` with a `Consumer` builder that reads `currentUserIdProvider` and threads the uid (or convert `MemberManagementScreen` to a `ConsumerWidget` and have it read the provider directly — pick whichever matches existing patterns better).

- **`lib/app/features/dashboard/application/dashboard_provider.dart` — DELETE.** Replaced by `dashboardEventsProvider` in `providers.dart`. Remove all imports.

- **`lib/app/core/database/app_database.dart`:**
  - Drop the FK on `Events.creatorId`: change `text().references(Users, #id)()` → `text()()`.
  - Bump `schemaVersion` from 4 → 5.
  - Add migration step `if (from < 5) { ... }`. SQLite cannot drop FKs in place; the migration must rebuild the table: create `events_new` without the FK, copy rows, drop `events`, rename. Confirm during implementation whether Drift's `customStatement` or `m.alterTable(TableMigration(events))` is the right tool.

*Patterns to follow:*

- Mirror lifecycle: read `TaskRepository._mirrors` and `disposeMirror` literally — the pattern is proven.
- Keep `firestoreProvider` as the seam for tests.
- SnackBar: capture the messenger before any `await`. Always.
- `dart:developer log(name: 'events', ...)` for repository errors, matching the existing convention.

*What to avoid:*

- Do NOT build a custom sync engine. Firestore SDK offline persistence is the queuing layer.
- Do NOT have Drift writes that bypass Firestore. Writes always go to Firestore first; Drift mirrors come from the listener.
- Do NOT add direct widget-to-EventRepository wiring outside the Riverpod graph.
- Do NOT remove the `Events` / `EventsDao` Drift schema — it remains the read cache on mobile/desktop.
- Do NOT migrate `CreateTaskScreen` or `JoinEventSheet` in this stage — separate spec.
</implementation>

<validation>
**Baseline automated coverage:**

*Logic / business rules (unit):*
- New: mapper test for `EventRepository._toDomain` (Firestore document → `EventModel`) covering all fields plus null-safe optionals.
- New: mapper test for `EventModel` → Firestore map (used by `createEvent`) — all fields present, server timestamps used for `createdAt`/`updatedAt`.
- For the audit, confirm `balance_ledger_test.dart` exercises the greedy settlement algorithm with at least one round-trip case.

*UI behavior (widget tests — new):*
- *Happy path:* submitting a valid form writes one document to `fake_cloud_firestore`'s `events` collection with the expected fields (`creatorId`, `adminIds`, `memberIds`, `status`, `title`, `description`, `eventType`, `startDate`, `currency`). Override `firestoreProvider` and `currentUserIdProvider` in the `ProviderScope`.
- *Failure path:* simulate a Firestore write failure (e.g., a fake that throws on `set`); assert the screen stays mounted, no Navigator pop occurs, and `Key('createEvent.error')` is visible.
- *Loading state:* while the future is pending, a progress indicator is visible inside the submit button and `Key('createEvent.submit')` is disabled.
- *Sign-out path:* with `currentUserIdProvider` overridden to `null`, tapping submit shows the "Sign-in required" error and Firestore is not written to. (Defensive — see user_flows.)
- *Dashboard wiring:* `DashboardScreen` shows `_EmptyState` when `dashboardEventsProvider` emits an empty list and shows `EventCard`s when it emits data. Use `dashboardEventsProvider` overridden with a controllable stream.

*Critical journey (robot — new):*
- Dashboard (empty) → tap Create Event → fill title → tap submit → assert the new event tile appears on the dashboard list. Use `fake_cloud_firestore` + a fake auth + an in-memory Drift DB so the journey exercises the full Firestore-Write / Drift-Read slice (Firestore listener emits the snapshot, mirror writes to Drift, dashboard re-renders).

**TDD expectations:**

Implement the fix as a strict vertical slice. RED → GREEN → REFACTOR per behavior, in this order:

1. RED: mapper test (Firestore doc → `EventModel`).
2. GREEN: minimal `EventRepository` skeleton + mapper.
3. RED: mapper test (`EventModel` → Firestore map).
4. GREEN.
5. RED: widget test "submit writes correct fields to Firestore" against `fake_cloud_firestore`.
6. GREEN: Riverpod wiring + `_submit` rewrite.
7. RED: failure-path test.
8. GREEN.
9. RED: loading-state test.
10. GREEN.
11. RED: sign-out test.
12. GREEN.
13. RED: dashboard wiring test (empty state + populated state).
14. GREEN.
15. RED: robot journey test.
16. GREEN.
17. REFACTOR: extract duplicated UI helpers; tighten naming.

**Required test seams + selectors:**

- `currentUserIdProvider`, `eventRepositoryProvider`, and `dashboardEventsProvider` must all be overridable in `ProviderScope`.
- `firestoreProvider` is overridable to inject `fake_cloud_firestore` (already a dev dependency at `pubspec.yaml:86`).
- Stable widget keys:
  - `Key('createEvent.submit')` on the Create Event button.
  - `Key('createEvent.error')` on the inline error widget.
  - `Key('createEvent.body.clamped')` already exists — reuse it.
  - `Key('dashboard.events.list')` on the rendered `ListView.separated` (helps the journey test).

**Mocking policy:**

- Prefer `fake_cloud_firestore` over hand-rolled fakes for Firestore.
- Use an in-memory Drift DB (`AppDatabase(NativeDatabase.memory())`) for the mirror in mobile-path tests.
- The only "mocked" boundary is `currentUserIdProvider`, and only in tests exercising the unauthenticated path.

**Audit validation:**
- Every "done" claim in `docs/v1-progress-audit.md` is reproducible by opening the cited file.
- Every "missing" claim links to a file or includes a Grep/Glob proof showing the absence.
- The launch-blockers list at the bottom answers "what's left for V1?" in under a minute of reading.

**Manual smoke (after Stage 2 lands):**
- iOS sim + web (`flutter run -d chrome --dart-define=FLAVOR=dev`): sign in, tap Create Event, fill title, submit. Verify the event tile appears on the dashboard immediately.
- Reload the page (web) / kill-and-restart (iOS): the event tile is still there (Firestore offline cache + server roundtrip).
- Open a second device signed in to the same account: the new tile appears within a few seconds (Firestore listener fan-out).
- Disable the network, create another event, observe the tile appears immediately (offline persistence + listener emits the pending mutation), then reconnect — verify the document lands in Firestore (via Console or a second device).
- Open the Firebase Console and confirm the new event document at `events/{id}` has `creatorId == auth uid`, `adminIds = [uid]`, `memberIds = [uid]`.
</validation>

<stages>
**Stage 1 — V1 Progress Audit**
- Output: `docs/v1-progress-audit.md` covering all five pillars + launch-blocker / V1.x follow-up split. Linked from this spec.
- Verify: every cell cites a file or function; reviewer can open each path and confirm.

**Stage 2 — Create Event Fix (Firestore-Write / Drift-Read)**
- Output: rewritten `EventRepository` (Firestore writes + Drift mirror), three new providers (`eventRepositoryProvider`, `dashboardEventsProvider`, `currentUserIdProvider`), Riverpod-aware `CreateEventScreen`, data-driven `DashboardScreen`, `MemberManagementScreen` uid threading, deleted `dashboard_provider.dart`, dropped FK on `Events.creatorId` with `schemaVersion` bump + migration. New mapper, widget, and journey tests.
- Verify: all tests green; manual smoke on iOS sim + web confirms cross-reload persistence and cross-device parity within seconds; offline write replays on reconnect.
</stages>

<done_when>
- `docs/v1-progress-audit.md` exists, is linked from this spec, covers all five pillars with done/missing claims grounded in file references, and ends with a launch-blockers / V1.x follow-ups split.
- The audit explicitly recommends deleting `lib/app/core/services/sync_engine.dart` and `lib/app/core/services/i_sync_service.dart` as dead code.
- The audit lists the silent-no-op pattern in `CreateTaskScreen` and `JoinEventSheet` as launch blockers if they remain unfixed.
- The Create Event button writes to Firestore at `events/{id}` with `creatorId = uid`, `adminIds = [uid]`, `memberIds = [uid]` and surfaces success or failure to the user — no silent no-op.
- The new event tile is visible on the dashboard immediately after creation, on both iOS and web, and persists across reload (Firestore offline cache).
- `DashboardScreen` consumes `dashboardEventsProvider` and renders a live event list; the hardcoded empty list at `dashboard_screen.dart:19` is gone.
- `currentUserIdProvider` exists in `providers.dart`; `app_router.dart:158` no longer passes `currentUserId: ''`.
- `lib/app/features/dashboard/application/dashboard_provider.dart` is deleted.
- The FK on `Events.creatorId → Users` is dropped; `schemaVersion` is bumped to 5 with a migration step.
- Widget tests cover happy path, failure, loading, sign-out, and dashboard wiring; one journey test covers dashboard → create → list.
- No custom sync engine has been introduced or revived.
</done_when>
