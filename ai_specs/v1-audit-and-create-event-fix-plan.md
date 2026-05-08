## Overview

V1 progress audit doc + Firestore-Write / Drift-Read fix for the create-event silent no-op. Mirror `TaskRepository` shape exactly. No custom sync engine.

**Spec**: `ai_specs/v1-audit-and-create-event-fix-spec.md` (commit `9f93273` — read for full requirements)

## Context

- **Structure**: feature-first under `lib/app/features/`; shared infra in `lib/app/core/`.
- **State management**: Riverpod 3; providers centralised in `lib/app/core/providers.dart`.
- **Reference implementations** (copy patterns verbatim):
  - `lib/app/features/tasks/data/task_repository.dart:17-117` — Firestore listener + Drift mirror lifecycle (`_firestoreSubs`, `_ensureFirestoreMirror`, `_mirrorSnapshot`, `disposeMirror`, `dispose`).
  - `lib/app/features/budget/data/expense_repository.dart:16-85` — same pattern with image-service injection.
  - `lib/app/core/providers.dart:108-127` — `taskRepositoryProvider` + `taskListProvider` shape.
  - `test/harness/tasks_harness.dart:35-91` — `fake_cloud_firestore` + in-memory Drift + `ProviderScope` overrides.
  - `test/journeys/tasks_journey_test.dart` — robot journey shape.
- **UID extraction pattern** (use verbatim): `switch (ref.watch(authProvider)) { Authenticated(:final user) => user.uid, _ => null }`.
- **Assumptions / Gaps**:
  - SQLite FK enforcement is off by default in Drift; if so, schema-text change + version bump is enough. If on, fall back to `m.alterTable(TableMigration(...))` rebuild. Verify in Phase 2.
  - `EventModel` needs `createdAt` + `updatedAt` fields added (currently absent).
  - `test/app/features/dashboard/event_repository_test.dart` will NOT survive the API rewrite — replace.
  - `dashboard_provider.dart` has no other importers — safe to delete.
  - `fake_cloud_firestore` does not produce real `FieldValue.serverTimestamp()` values; assertions use `isA<Timestamp>()` or are timestamp-agnostic.

## Plan

### Phase 1: V1 Progress Audit ✅

- **Goal**: Stand up `docs/v1-progress-audit.md` so the team has a concrete V1 punch list.
- [x] `docs/v1-progress-audit.md` — five-pillar matrix (Pillar / V1 Intent / Done / Missing / Severity) with file refs for every claim.
- [x] Verify Drift schema coverage: events, tasks, expenses, expense_splits, chat_messages, users, task_checklist_items (`lib/app/core/database/app_database.dart`).
- [x] Locate greedy settlement algorithm (`lib/app/features/budget/domain/models/balance_ledger.dart`) + cite `test/app/features/budget/balance_ledger_test.dart`.
- [x] Verify urgent-message FCM path: `functions/src/events/onUrgentMessageCreated.ts` exists + invoked from chat write path.
- [x] Verify pay-link deep links: `lib/app/features/budget/data/pay_link_builder.dart` covers Venmo / CashApp / Zelle (or document gaps). **Zelle is missing — flagged as launch blocker.**
- [x] Verify receipt upload + silent compression: `image_picker` → `firebase_image_service` → Storage path.
- [x] Verify web parity primitives: `responsive_shell.dart`, `content_max_width.dart`, PDF/CSV exports.
- [x] Verify account deletion CF: solitary-event wipe, anonymise to `deleted_user`, drop Auth user (`functions/src/account/deleteUserAccount.ts`).
- [x] Verify auto user-doc creation: `AuthNotifier._ensureUserDoc` (`lib/app/features/auth/application/auth_provider.dart:80-109`).
- [x] Verify Firestore offline persistence is enabled (`firebase_service.dart` or equivalent init); flag if absent. **Mobile defaults OK; web persistence NOT enabled — flagged as launch blocker.**
- [x] Recommend deletion of `lib/app/core/services/sync_engine.dart` + `lib/app/core/services/i_sync_service.dart` as dead code. (Plus stale `test/app/features/profile/profile_test.dart` that references SyncEngine.)
- [x] Section: V1 launch blockers (CreateEventScreen, CreateTaskScreen, JoinEventSheet silent-no-ops; DashboardScreen hardcoded empty list; `currentUserId: ''` placeholder at `app_router.dart:158`; web Firestore persistence; Zelle UX).
- [x] Section: V1.x follow-ups.
- [x] Update spec `ai_specs/v1-audit-and-create-event-fix-spec.md` to link the audit doc.
- [x] Verify: every "done" claim opens to a file; every "missing" claim has a file ref or grep proof.

### Phase 2: Create Event Fix — Firestore-Write / Drift-Read vertical slice

- **Goal**: Tap Create Event → document lands at `events/{id}` in Firestore → tile appears on dashboard immediately on iOS + web. Mirror `TaskRepository` shape exactly.

**Foundation:**

- [ ] `lib/app/features/dashboard/domain/models/event.dart` — add `createdAt` and `updatedAt` (`DateTime?`, optional, defaults `null`).
- [ ] `lib/app/core/database/app_database.dart:29` — drop FK on `Events.creatorId` (`text()()`); bump `schemaVersion` 4 → 5; add `if (from < 5)` migration. Use `m.alterTable(TableMigration(events))` if FK enforcement is on; pass-through otherwise.

> **CRITICAL (carried from `/work` invocation):** When bumping `schemaVersion` to 5 and dropping the FK on `Events.creatorId`, write a **safe** `onUpgrade` migration block. SQLite cannot drop foreign keys in place — the migration must rebuild the table (`m.alterTable(TableMigration(events))`) or use `customStatement` to recreate-copy-rename. After modifying the table definition, **MUST run `dart run build_runner build -d`** to regenerate `app_database.g.dart` and the DAOs **before** running any tests. Do not proceed past this step until build_runner completes successfully.

**Repository rewrite (mirror TaskRepository):**

- [ ] TDD: Firestore doc → `EventModel` mapper — all fields, null-safe optionals, `Timestamp` → `DateTime` parsing.
- [ ] TDD: `EventModel` → Firestore map — server timestamps for `createdAt` / `updatedAt`, lists serialise as JSON arrays not strings.
- [ ] TDD: Drift row → `EventModel` mapper — adminIds/memberIds JSON decode, status enum from string.
- [ ] `lib/app/features/dashboard/data/event_repository.dart` — full rewrite. Constructor takes `EventsDao` + `FirebaseFirestore`. `Map<String, StreamSubscription> _firestoreSubs` keyed by **uid**. Methods: `_ensureFirestoreMirror(uid)`, `_mirrorSnapshot(uid, snap)` (upsert + delete-not-in-set), `disposeMirror(uid)`, `dispose()`, `Future<void> createEvent(EventModel)` (Firestore `set` with server timestamps, throws on failure), `Stream<List<EventModel>> watchEventsForUser(String uid)` (Drift-backed on mobile, raw Firestore stream on web via `kIsWeb`).
- [ ] TDD: `createEvent` writes one document at `events/{id}` with correct fields against `fake_cloud_firestore`.
- [ ] TDD: listener mirrors snapshot into Drift (`NativeDatabase.memory()`) on add.
- [ ] TDD: listener removes Drift rows when Firestore docs are deleted.
- [ ] TDD: `disposeMirror(uid)` cancels the subscription; second call is a no-op.

**Providers (`lib/app/core/providers.dart`, near `taskRepositoryProvider`):**

- [ ] Add `currentUserIdProvider` (`Provider<String?>`) deriving uid from `authProvider` via sealed-state switch.
- [ ] Add `eventRepositoryProvider` (`Provider<EventRepository>`) wiring `EventsDao(databaseProvider)` + `firestoreProvider`; `ref.onDispose(repo.dispose)`.
- [ ] Add `dashboardEventsProvider` (`StreamProvider<List<EventModel>>`): null uid → `Stream.value([])`; else `repo.watchEventsForUser(uid)`; `ref.onDispose(() => repo.disposeMirror(uid))`.
- [ ] TDD: `currentUserIdProvider` returns uid when `Authenticated`, null when `Unauthenticated` / `AuthInitial` / `AuthLoading` / `AuthError`.
- [ ] TDD: `dashboardEventsProvider` emits `[]` when uid is null.

**Create Event screen rewrite:**

- [ ] `lib/app/features/dashboard/presentation/create_event_screen.dart` — convert to `ConsumerStatefulWidget`. Remove `onSubmit` parameter. `_submit`: validate; capture `final messenger = ScaffoldMessenger.of(context);` BEFORE `await`; read uid from `currentUserIdProvider` (null → "Sign-in required" error); set `_isSubmitting`; build `EventModel(creatorId: uid, adminIds: [uid], memberIds: [uid], status: EventStatus.active, ...)`; `await ref.read(eventRepositoryProvider).createEvent(event)`; on success `if (mounted) Navigator.pop(context); messenger.showSnackBar(...);` on failure clear flag + show inline error. Add `Key('createEvent.submit')` and `Key('createEvent.error')`.
- [ ] TDD: valid submit writes correct fields to `fake_cloud_firestore` (assertion on the actual Firestore document, not on a mocked notifier).
- [ ] TDD: write failure → screen stays mounted, no `Navigator.pop`, `Key('createEvent.error')` visible.
- [ ] TDD: in-flight → `Key('createEvent.submit')` disabled + progress indicator visible.
- [ ] TDD: `currentUserIdProvider == null` → "Sign-in required" error, Firestore not written.

**Dashboard wiring:**

- [ ] `lib/app/features/dashboard/presentation/dashboard_screen.dart:19` — replace `final events = <EventModel>[];` with `ref.watch(dashboardEventsProvider).when(...)`; loading → centered `CircularProgressIndicator`; error → inline error widget; empty → existing `_EmptyState`; data → existing `ListView.separated`. Add `Key('dashboard.events.list')`.
- [ ] TDD: dashboard renders `_EmptyState` on empty stream; renders `EventCard`s on data stream.

**Cleanup + uid threading:**

- [ ] Delete `lib/app/features/dashboard/application/dashboard_provider.dart`.
- [ ] Delete `test/app/features/dashboard/event_repository_test.dart` (API replaced; new tests cover the rewrite).
- [ ] `lib/app/core/router/app_router.dart:158` — replace `currentUserId: ''` with a `Consumer` reading `currentUserIdProvider` (or convert `MemberManagementScreen` to read it directly — pick whichever matches existing patterns).

**Critical journey test (robot):**

- [ ] `test/journeys/create_event_journey_test.dart` — mirror `test/journeys/tasks_journey_test.dart`. Empty dashboard → tap Create Event → fill title → tap submit → assert event tile visible on dashboard. Uses `fake_cloud_firestore` + in-memory Drift.
- [ ] Add `test/harness/dashboard_harness.dart` (or extend an existing harness) following `test/harness/tasks_harness.dart:35-91` shape.
- [ ] Required selectors: `Key('createEvent.submit')`, `Key('createEvent.error')`, `Key('dashboard.events.list')`, `Key('createEvent.body.clamped')` (existing).
- [ ] Required seams (overridden in `ProviderScope`): `firestoreProvider`, `databaseProvider`, `currentUserIdProvider`, `eventRepositoryProvider`, `authProvider`.

**Verify:**

- [ ] `flutter analyze` — zero issues.
- [ ] `flutter test` — full suite green (mappers, repo lifecycle, providers, screen states, dashboard wiring, journey).
- [ ] Manual smoke iOS sim: create event → tile appears → kill-and-restart → tile persists.
- [ ] Manual smoke web (`flutter run -d chrome --dart-define=FLAVOR=dev`): same flow + page reload → tile persists.
- [ ] Manual smoke offline: airplane mode → create → tile appears immediately → reconnect → confirm doc in Firebase Console at `events/{id}` with `creatorId == auth uid`, `adminIds = [uid]`, `memberIds = [uid]`.

## Risks / Out of scope

**Risks:**

- **SQLite FK migration:** if FK enforcement is enabled in Drift, schema-text change alone won't drop the constraint — needs `TableMigration` table-rebuild. Check first; fall back if needed. On-disk events on existing devices must migrate cleanly.
- **Listener fan-out volume:** `events.where('memberIds', arrayContains: uid)` returns every event the user belongs to. Fine for V1; flag for V1.x if read costs spike.
- **`fake_cloud_firestore` server-timestamp gaps:** `FieldValue.serverTimestamp()` doesn't materialise to a real `Timestamp` in the fake. Use `isA<FieldValue>()` or `isA<Timestamp>()` rather than exact equality in mapper tests.

**Out of scope:**

- `CreateTaskScreen` (`create_task_screen.dart:73`) silent-no-op — tracked in audit, separate spec.
- `JoinEventSheet` callback wiring — same pattern, separate spec.
- Custom sync engine — explicitly forbidden by spec `<boundaries>`.
- Migrating `TaskRepository` / `ExpenseRepository` / `ChatRepository` to a different pattern — they already match.
- OPFS persistence for Drift on web — unnecessary; web reads directly from Firestore stream.
