## Overview

Build a shared `EmptyStatePlaceholder` widget (lottie + title + subtitle + optional CTA + icon fallback), migrate existing ad-hoc empty states to it, then ship a cross-event "My Tasks" screen at `/tasks` composed from existing Riverpod streams. Branded stubs for Chat + Budget complete the polish.

**Spec**: `ai_specs/empty-state-placeholder-spec.md` (numbered refs below match the spec)

## Context

- **Structure**: feature-first under `lib/app/features/<feature>/{data,domain,application,presentation}`; shared widgets at `lib/app/core/widgets/`; i18n at `lib/app/core/i18n/app_strings.dart`; test mirror under `test/app/...` + harnesses at `test/harness/`.
- **State management**: Riverpod 3, legacy syntax (no `@riverpod` codegen). Canonical streams already exist:
  - `dashboardEventsProvider` (`lib/app/core/providers.dart:135`) — `StreamProvider<List<EventModel>>`. Reuse, don't duplicate.
  - `taskListProvider` (line 173) — `StreamProvider.family<List<TaskModel>, String>` keyed by `eventId`; already has `disposeMirror` cleanup hook.
  - `currentUserIdProvider` (line 114) — `Provider<String?>`; nullable, requires short-circuit before family invocation.
- **Reference implementations**:
  - `lib/app/core/widgets/loading_animation.dart:17` — canonical `Lottie.asset(... errorBuilder: (_, _, _) => fallback)` pattern.
  - `lib/app/features/dashboard/presentation/dashboard_screen.dart:79` — `_EmptyState` (no events) to migrate; CTA opens `JoinEventSheet.show(context: context)`.
  - `lib/app/features/tasks/presentation/task_list_screen.dart:157` — `_EmptyState` (filter-aware) + `_GroupHeader` (lines 130–154) to migrate; keys `tasks.list.emptyState` + `tasks.list.emptyState.clear` MUST survive.
  - `lib/app/core/i18n/app_strings.dart:27` — `AppStrings` sub-object pattern; add `ChatStrings`/`BudgetStrings`/`DashboardStrings` following the existing shape.
  - `lib/app/core/router/app_router.dart:215/224/232` — three `_PlaceholderScreen` stubs; the class at line 274 gets deleted in Phase 5.
  - Test harness pattern: `test/harness/dashboard_harness.dart` + `test/harness/tasks_harness.dart` — `_StubAuthNotifier`, `FakeFirebaseFirestore`, `NativeDatabase.memory()`.
- **Assumptions/Gaps**:
  - `context.go(AppRoutes.dashboard)` switches the active `StatefulShellRoute.indexedStack` branch when invoked from another branch (go_router default). No new harness needed for the screen-level journey test (per spec's explicit scope choice).
  - Lottie failures surface async via `errorBuilder`; widget tests pump ≥ 3 × 50 ms frames and avoid `pumpAndSettle` (lottie loops).
  - Phase 5 of the prior tasks-ux-overhaul plan already shipped `TaskTile` with `currencyCode` + Phase 3 populates `checklistItems`. The cross-event provider passes per-row `event.currency` into each tile.

## Plan

### Phase 1: `EmptyStatePlaceholder` widget + dashboard migration (thin vertical slice)

- **Goal**: Ship the shared widget end-to-end through ONE call site (the dashboard "no events" state) so the API + i18n flow are proven before scaling.
- [x] `lib/app/core/widgets/empty_state_placeholder.dart` — `StatelessWidget`; public API per spec req 1 (`title, subtitle?, ctaLabel?, onCta?, ctaKey?, lottieAsset = 'assets/animations/empty_state.json', iconFallback = Icons.inbox_outlined, lottieHeight = 160`); `Lottie.asset(..., errorBuilder: ...)` + dedupe-once `developer.log(name: 'empty-state')`; vertical layout per spec req 5; test-stable keys per req 7
- [x] `lib/app/core/i18n/app_strings.dart` — add `DashboardStrings` sub-object (`noEventsTitle`, `noEventsSubtitle`, `joinWithCode`); wire into `AppStrings` + `_EnglishStrings` impls
- [x] `lib/app/features/dashboard/presentation/dashboard_screen.dart` — replace private `_EmptyState` body with `EmptyStatePlaceholder(...)`; CTA fires `JoinEventSheet.show(context: context)`; delete the private class
- [x] TDD: widget renders title + optional subtitle + optional CTA via `emptyState.title`/`subtitle`/`cta` keys; CTA tap fires `onCta`
- [x] TDD: when `ctaLabel`/`onCta` null → no button rendered
- [x] TDD: bad `lottieAsset` path → after ≥ 3 × 50 ms pumps, `emptyState.iconFallback` Icon visible (NO `pumpAndSettle` — lottie loops; spec validation block)
- [x] TDD: `ctaKey` forwarded onto the OutlinedButton (passthrough assertion)
- [x] TDD: dashboard "no events" state still renders new widget; Join button still present + tappable
- [x] Verify: `flutter analyze` clean (only pre-existing `TableMigration` warning); `flutter test test/app/core/widgets/empty_state_placeholder_test.dart test/app/features/dashboard/`

### Phase 2: Migrate `task_list_screen` empty states + extract `TasksGroupHeader`

- **Goal**: Migrate the per-event Tasks list empty state without breaking the Phase 5 key contracts (`tasks.list.emptyState`, `tasks.list.emptyState.clear`). Extract `_GroupHeader` to a shared `TasksGroupHeader` so the upcoming `MyTasksScreen` reuses it.
- [x] `lib/app/features/tasks/presentation/widgets/tasks_group_header.dart` — extract Phase 5's `_GroupHeader` (label + sage thin divider; existing visual unchanged); public API `TasksGroupHeader({Key? key, required String label})`
- [x] `lib/app/features/tasks/presentation/task_list_screen.dart` — delete private `_GroupHeader`; consume `TasksGroupHeader`. Delete private `_EmptyState`; replace with `EmptyStatePlaceholder` wrapped in `KeyedSubtree(key: const Key('tasks.list.emptyState'))` so the outer key survives. CTA case uses `ctaKey: const Key('tasks.list.emptyState.clear')`. Branch on `filter.hasActiveFilters`: active → `emptyNoMatch` + Clear; inactive → `emptyNoTasksYet` + new `emptyNoTasksHelp` subtitle, no CTA
- [x] `lib/app/core/i18n/app_strings.dart` — extend `TasksStrings` + `_EnglishTasksStrings` with `emptyNoTasksHelp` ("Tap + to create your first task")
- [x] TDD: existing Phase 5 tests (`test/app/features/tasks/task_list_screen_test.dart`) pass UNCHANGED — regression on both outer + inner keys
- [x] TDD: `TasksGroupHeader` renders label + sage divider; existing `task_list_screen` group header tests still find `Key('tasks.list.groupHeader.${key}')` (the key contract is parent-applied, unaffected by extraction)
- [x] Verify: `flutter analyze && flutter test test/app/features/tasks/`

### Phase 3: `myAssignedTasksProvider` (pure Riverpod composition)

- **Goal**: Compose existing `dashboardEventsProvider` + `taskListProvider(eventId)` into a cross-event aggregate. No UI yet — just the provider + value class + comprehensive tests. CI on stream-folding semantics.
- [x] `lib/app/features/tasks/application/my_assigned_tasks_provider.dart` — `MyAssignedTaskRow { final TaskModel task; final EventModel event; }` (plain Dart immutable class, two `final` fields). `final myAssignedTasksProvider = Provider.family<AsyncValue<List<MyAssignedTaskRow>>, String>((ref, uid) {...})` per spec req 9: `ref.watch(dashboardEventsProvider)` → for each event `ref.watch(taskListProvider(event.id))` → filter by `assigneeId == uid` → flatten → `AsyncValue.data(rows)`. Any input `loading` → `loading()`; any input `error` → `error(...)`.
- [x] TDD: composition — two events seeded via overrides, one task each, only one matches uid → returns single row with correct `task` + `event` references
- [x] TDD: filter — task with mismatching `assigneeId` excluded even when in user's event
- [x] TDD: ordering — events follow `dashboardEventsProvider` order; tasks within an event follow source-list order
- [x] TDD: loading propagation — when ANY input is `AsyncValue.loading()`, provider returns `loading()`
- [x] TDD: error propagation — when `dashboardEventsProvider` errors → `error(...)`; when any `taskListProvider(...)` errors → `error(...)`
- [x] TDD: empty events list → empty data list, NOT loading or error
- [x] Verify: `flutter analyze && flutter test test/app/features/tasks/my_assigned_tasks_provider_test.dart`

### Phase 4: `MyTasksScreen` at `/tasks`

- **Goal**: Consume Phase 3 provider; render loading / empty-with-events / empty-no-events / null-uid / non-empty branches; wire route. Robot journey test for the screen-level empty-state CTA flow.
- [x] `lib/app/features/tasks/presentation/my_tasks_screen.dart` — `ConsumerWidget`. Reads `currentUserIdProvider` first; null → short-circuit `EmptyStatePlaceholder(title: signInRequiredTitle)`, NO family invocation (spec req 8 + 21). Non-null → `myAssignedTasksProvider(uid).when(...)`:
  - `loading: () => LoadingAnimation()` (existing widget at `lib/app/core/widgets/loading_animation.dart`)
  - `error: (e, st) => EmptyStatePlaceholder(title: 'Could not load tasks', subtitle: e.toString(), lottieAsset: 'assets/animations/error.json')` + `developer.log(name: 'tasks.myTasks')`
  - `data: rows` → empty → `EmptyStatePlaceholder` with copy/CTA adapting to event count (req 23 — events present → `myTasksEmptySubtitle` + `openDashboardCta`; zero events → `myTasksEmptySubtitleNoEvents` + `createFromDashboardCta`). Both CTAs `() => context.go(AppRoutes.dashboard)`.
  - `data: rows` non-empty → `ListView`, grouped by event via `TasksGroupHeader(label: event.title)` then `TaskTile`s. Tap → `context.push('/dashboard/event/${row.event.id}/tasks/${row.task.id}')`. Each tile passes `currencyCode: row.event.currency`.
- [x] AppBar title from `context.strings.tasks.myTasksAppBarTitle` — no literals
- [x] `lib/app/core/i18n/app_strings.dart` — extend `TasksStrings` with `myTasksAppBarTitle, myTasksEmptyTitle, myTasksEmptySubtitle, myTasksEmptySubtitleNoEvents, openDashboardCta, createFromDashboardCta, signInRequiredTitle`
- [x] `lib/app/core/router/app_router.dart` — replace `/tasks` branch's `_PlaceholderScreen(title: 'Tasks')` (line 215) with `const MyTasksScreen()`. Do NOT delete `_PlaceholderScreen` yet (Phase 5 cleans it up).
- [x] TDD: loading branch → `LoadingAnimation` visible; no empty state, no list
- [x] TDD: empty-with-events → `myTasksEmptySubtitle` + `openDashboardCta` text rendered
- [x] TDD: empty-no-events → `myTasksEmptySubtitleNoEvents` + `createFromDashboardCta`
- [x] TDD: null-uid short-circuit → `signInRequiredTitle` rendered; `myAssignedTasksProvider` NEVER subscribed (assert via override counter)
- [x] TDD: non-empty → one `TasksGroupHeader` per distinct event; tile `onTap` fires the captured `context.push(...)` (override navigation seam — exposed as `onOpenTask` constructor param; `onOpenDashboard` covers the CTA)
- [x] Robot: `test/journeys/tasks_tab_empty_state_journey_test.dart` — screen-level scope per spec (pump `MyTasksScreen` in minimal `ProviderScope` + `MaterialApp`; seed `data: []` + zero events; assert empty state visible; tap CTA → captured callback fires). Full `StatefulShellRoute` harness deferred per spec.
- [x] Verify: `flutter analyze && flutter test`

### Phase 5: Chat + Budget tab stubs; drop `_PlaceholderScreen`

- **Goal**: Replace the remaining two `_PlaceholderScreen` stubs with branded `EmptyStatePlaceholder` screens and delete the now-dead class. Pure follow-up — depends on Phase 1's widget.
- [x] `lib/app/features/chat/presentation/chat_tab_placeholder_screen.dart` — `StatelessWidget`; AppBar title "Chat"; body `EmptyStatePlaceholder(title: tabEmptyTitle, subtitle: tabEmptySubtitle, ctaLabel: openDashboardCta, onCta: () => context.go(AppRoutes.dashboard))` (optional `onOpenDashboard` test seam mirrors `MyTasksScreen`)
- [x] `lib/app/features/budget/presentation/budget_tab_placeholder_screen.dart` — same shape, `BudgetStrings.tabEmpty*`
- [x] `lib/app/core/i18n/app_strings.dart` — add `ChatStrings` (`tabEmptyTitle`, `tabEmptySubtitle`) + `BudgetStrings` (same fields) sub-objects + English impls; wire into `AppStrings`
- [x] `lib/app/core/router/app_router.dart` — replace `/chat` and `/budget` branches' `_PlaceholderScreen(...)` with the two new screens; **delete** the `_PlaceholderScreen` class since no callers remain
- [x] TDD: each tab screen renders `EmptyStatePlaceholder` with the expected title key; CTA fires the navigation seam
- [x] Verify: `flutter analyze` clean; `flutter test`; grep confirms `_PlaceholderScreen` class is gone (`! grep -r "_PlaceholderScreen" lib/`)

## Risks / Out of scope

**Risks**:
- Provider lifecycle: each event the user belongs to spawns one `taskListProvider(eventId)` subscription via `ref.watch`. Riverpod's `disposeMirror` hook covers cleanup, but a user in 25+ events will fan out that many Firestore listeners. Spec'd as acceptable until profiling proves otherwise; flagged because `myAssignedTasksProvider` is the load-bearing piece of Phase 3.
- Lottie test seam timing: the spec mandates ≥ 3 × 50 ms pumps and forbids `pumpAndSettle`. Easy to forget in Phase 1; the validation block enforces it. If a test sneaks in `pumpAndSettle` against `EmptyStatePlaceholder`, it will hang.
- Phase 2 key-contract preservation: the existing Phase 5 task-list tests probe `Key('tasks.list.emptyState')` AND `Key('tasks.list.emptyState.clear')` on specific widget types. The migration wraps `EmptyStatePlaceholder` in `KeyedSubtree` (outer) and passes `ctaKey` (inner). Forgetting either breaks the existing test suite.

**Out of scope** (deferred per spec):
- Server-side Firestore `collectionGroup` query for tasks; revisit if listener fan-out becomes a real cost.
- Custom-coded Dart animation replacing Lottie altogether; the user said they'll swap `empty_state.json` later — the widget contract is stable either way.
- Real cross-event Chat / Budget aggregations; both tabs are empty-state-only V1.
- Cross-event filter/sort/search on `MyTasksScreen` — the user picked the simple flat list.
- Full `StatefulShellRoute` test harness (a "TabsJourneyHarness" pumping the real bottom-nav); robot journey is screen-level only.
- New lottie animations under `assets/animations/`; reuse the existing `empty_state.json` (default) and `error.json` (error state) only.
