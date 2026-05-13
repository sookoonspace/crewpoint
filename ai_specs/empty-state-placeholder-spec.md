<goal>
Replace the three currently-stub top-level tabs (Tasks, Chat, Budget) with a real, branded experience and ship a reusable `EmptyStatePlaceholder` widget the rest of the app adopts so every "nothing here yet" surface looks and feels the same.

Three intertwined deliverables:

1. **`EmptyStatePlaceholder` widget** — a `StatelessWidget` under `lib/app/core/widgets/`. Renders a lottie animation (default `assets/animations/empty_state.json`), a title, optional subtitle, optional CTA button, and an icon fallback when the lottie asset is missing/broken. One shape, one place to evolve the look. Today's stub is `assets/animations/empty_state.json`; the user has said they'll swap it for a polished animation or hand-coded animation later — the widget contract is stable either way.

2. **`MyTasksScreen` at `/tasks`** — Replaces the temporary `_PlaceholderScreen(title: 'Tasks')` on the top-level Tasks tab. Aggregates tasks assigned to the current user across **every event they belong to**, grouped by event. Reuses `TaskTile` for each row. When empty, renders `EmptyStatePlaceholder` with a CTA that switches to the Dashboard tab so the user can open / join an event.

3. **Branded stubs for Chat + Budget tabs + migration of legacy empty states** — Chat and Budget tabs each render `EmptyStatePlaceholder` with tab-specific copy. The dashboard's "no events yet" empty state and the per-event Tasks list's "no tasks yet" / "no tasks match this filter" empty states migrate to the same widget so the entire app's "nothing here" experience is one design.

Beneficiaries: users who open the app and tap the Tasks/Chat/Budget tabs today see "Tasks" in plain text on a blank screen — bad first impression and a sign the feature is unfinished. After this PR they see a branded, animated empty state with a clear next step. Anyone with assigned tasks across multiple events gets a single screen showing them all without hunting through events.
</goal>

<background>
**Tech stack & conventions** (relevant for this PR):

- Flutter 3.11+ / Dart 3.x; Riverpod 3 (`riverpod_annotation` codegen); `go_router` 14 with `StatefulShellRoute.indexedStack` driving the bottom navigation.
- `lottie: ^3.3.1` is already a dependency; `assets/animations/` already ships `empty_state.json`, `error.json`, `loading.json`, `profile.json`, `sign_out.json`, `success.json`. `pubspec.yaml`'s `flutter.assets` already lists `assets/animations/` — new lotties land here.
- Existing lottie call sites for reference style: `lib/app/core/widgets/loading_animation.dart`, `lib/app/core/widgets/network_image_with_placeholder.dart`, `lib/app/features/profile/presentation/widgets/sign_out_sheet.dart`.
- Brand palette in `lib/app/core/constants/app_colors.dart`. Tab icons + outline buttons follow the `AppColors.sage` look; destructive uses `AppColors.terracotta`; background is `AppColors.cream`.
- `AppRoutes.tasks` = `/tasks`, `AppRoutes.chat` = `/chat`, `AppRoutes.budget` = `/budget`. The bottom-nav `StatefulShellBranch` points at these. Each currently builds `_PlaceholderScreen(title: '<Tab Name>')` (see `lib/app/core/router/app_router.dart` lines ~215 / ~224 / ~232).
- Tasks data layer: `taskRepositoryProvider` watches Firestore tasks for one event at a time (`watchTasksByEventId(eventId)`), mirroring into Drift via `_ensureFirestoreMirror(eventId)`. The mirror only spins up after the first watch call for that event.
- Events data layer: `eventRepositoryProvider.watchEventsForUser(uid)` already streams the user's events list (Firestore-Write + Drift-Read).
- TasksStrings + `_EnglishTasksStrings` (`lib/app/core/i18n/app_strings.dart`) is the canonical i18n pipe for every user-facing label in this PR. **Do not hardcode literals** in widget files.
- Phase 3 + 4 of the tasks-ux-overhaul plan already populate `TaskModel.checklistItems` from Drift and ship the `TaskTile` redesign. This PR builds on that work — no schema changes needed.

**Files to examine before implementing:**

- `lib/app/core/router/app_router.dart` (the `_PlaceholderScreen` stubs in the StatefulShellRoute branches; the route shape).
- `lib/app/core/widgets/loading_animation.dart` and `lib/app/core/widgets/network_image_with_placeholder.dart` for the existing `Lottie.asset` usage pattern (look-and-feel + `errorBuilder` convention).
- `lib/app/features/dashboard/presentation/dashboard_screen.dart` — current `_EmptyState` (no events). Pattern to migrate.
- `lib/app/features/tasks/presentation/task_list_screen.dart` — current `_EmptyState` (no tasks yet / no match + Clear filters). Pattern to migrate.
- `lib/app/features/tasks/data/task_repository.dart` — `watchTasksByEventId`, `_ensureFirestoreMirror` so we understand how cross-event aggregation can work without breaking the existing per-event subscription model.
- `lib/app/features/dashboard/data/event_repository.dart` — `watchEventsForUser(uid)` for the events list the cross-event provider will iterate over.
- `lib/app/core/database/daos/tasks_dao.dart` — for the new "tasks assigned to uid across all eventIds" query.
- `lib/app/core/i18n/app_strings.dart` — `TasksStrings` extension for new labels.

**Out of scope** (deferred):

- A real Tasks-tab feature richer than "cross-event My tasks" (e.g., across-event search, sort, filter, group). The empty + flat-list scaffold is V1.
- A real Chat tab feature (aggregated chats across events). Just the empty-state placeholder; clicking the CTA takes the user to the Dashboard.
- A real Budget tab feature (aggregated balances across events). Same shape — empty-state CTA only.
- Server-side Firestore `collectionGroup` query for tasks. V1 uses a Drift-mirror-warm-up strategy because rules + composite index work would expand scope.
- Lottie animation polish — the user explicitly said they'll swap `empty_state.json` later, so we treat it as a stable contract: caller can pass a different `lottieAsset` or rely on the default.
- Custom-coded Dart animations replacing Lottie altogether — also a future swap.
- Empty-state copy translation beyond English — strings flow through the existing `app_strings.dart` extension; localisation happens when the project as a whole adopts `flutter_localizations`.
</background>

<user_flows>

## Tasks tab — no assigned tasks anywhere

**Primary:**

1. User taps the Tasks bottom-nav tab.
2. `MyTasksScreen` renders with `EmptyStatePlaceholder` — lottie animation, title "No tasks assigned to you", subtitle "Open an event from the Dashboard to view or create tasks.", and a `Open Dashboard` outlined sage button.
3. User taps the button → `context.go(AppRoutes.dashboard)` switches the bottom-nav tab to Dashboard.
4. From Dashboard, the user opens an event and (eventually) assigns themselves a task. Returning to the Tasks tab now shows the task in the cross-event list.

## Tasks tab — has assigned tasks across events

**Primary:**

1. User taps the Tasks tab.
2. `MyTasksScreen` shows a scrolling list. Tasks are grouped by event title (largest visual element is the event name as a group header; tiles below).
3. Tap a tile → navigate to `/dashboard/event/<eventId>/tasks/<taskId>` via `context.push(...)` (reuses the existing event-scoped task detail screen).
4. Pull-to-refresh re-emits from the underlying providers (no extra logic; Riverpod handles).

## Chat / Budget tabs (Empty-state-only V1)

**Primary:**

1. User taps the Chat (or Budget) tab.
2. `EmptyStatePlaceholder` renders with a tab-specific title and CTA pointing at the Dashboard.
3. User taps the CTA → bottom-nav switches to Dashboard.

## Existing surfaces (migrated)

- Dashboard with no events: existing `_EmptyState` swapped for the shared widget. Copy: "No events yet" / "Create an event or join one with a code" / `Join with Code` button (unchanged behaviour — opens `JoinEventSheet`).
- Per-event tasks list, empty without filters: shared widget with "No tasks yet" + "Tap + to create your first task" (no CTA — the FAB is the create affordance).
- Per-event tasks list, empty with active filters: shared widget with "No tasks match this filter" + `Clear filters` button (same key as today — `tasks.list.emptyState.clear`).

## Error / fallback flows

- **Lottie asset missing or fails to decode** → `EmptyStatePlaceholder` renders the `iconFallback` Icon (default `Icons.inbox_outlined`) in `AppColors.lightGrey` at 64px. No animation; everything else (title, subtitle, CTA) renders normally. Logged once via `developer.log(name: 'empty-state')` so it surfaces in `flutter logs` without spamming.
- **No assigned tasks AND no events at all** → Tasks tab still renders the empty state. The CTA copy adapts: when the user has zero events, "Create an event from the Dashboard" instead of "Open an event from the Dashboard"; the destination is the same.
- **Network offline on first cold start** → events and tasks streams emit empty initially; the Tasks tab shows the empty state until Firestore reconnects + Drift mirror catches up. Then the list populates without manual refresh.

</user_flows>

<requirements>

**Functional — `EmptyStatePlaceholder` widget:**

1. New file `lib/app/core/widgets/empty_state_placeholder.dart`. `StatelessWidget`. Public API: `key, title (required), subtitle?, ctaLabel?, onCta?, ctaKey?, lottieAsset = 'assets/animations/empty_state.json', iconFallback = Icons.inbox_outlined, lottieHeight = 160`. The optional `ctaKey` is forwarded onto the `OutlinedButton` so call sites that need to preserve a legacy key (e.g. the migrated `task_list_screen` empty state) can do so without wrapping subtrees.
2. When the CTA pair is set (both `ctaLabel != null` and `onCta != null`), render an `OutlinedButton` styled with `foregroundColor: AppColors.sage` + `side: BorderSide(color: AppColors.sage)`. When either is null, render no button.
3. Lottie renders via `Lottie.asset(lottieAsset, height: lottieHeight, repeat: true, errorBuilder: ...)`. The `errorBuilder` returns the icon-fallback container (described below) AND logs via `developer.log` exactly once per call site (use a `static final Set<String> _loggedAssets = {}` keyed on `lottieAsset` to dedupe — failure to load the same asset twice should not spam logs).
4. Icon fallback: `Icon(iconFallback, size: 64, color: AppColors.lightGrey)` centered. Used by `errorBuilder` AND directly when `lottieAsset` is `null` (caller intentionally opts out of animation).
5. Vertical layout, centered: lottie/icon (160 px tall) → 16 px gap → title (`titleMedium`, `AppColors.charcoal`) → 8 px gap → subtitle (`bodySmall`, `AppColors.mediumGrey`, centered, max 2 lines, ellipsis) → 16 px gap → optional CTA button. Title is required; everything else conditional.
6. Wraps the column in a `Center` + `Padding(EdgeInsets.symmetric(horizontal: AppSpacing.xl))` so long subtitles wrap nicely on narrow screens.
7. Test-stable key contract: title `Text` is keyed `emptyState.title`, subtitle `Text` keyed `emptyState.subtitle`, CTA button keyed `emptyState.cta`, icon-fallback Icon keyed `emptyState.iconFallback`. The lottie itself is keyed `emptyState.lottie` (when rendered).

**Functional — `MyTasksScreen` + `myAssignedTasksProvider`:**

8. New file `lib/app/features/tasks/presentation/my_tasks_screen.dart`. `ConsumerWidget`. Reads `currentUserIdProvider` first. **If null** (auth race), renders `EmptyStatePlaceholder(title: TasksStrings.signInRequiredTitle)` and returns — the family provider is never invoked, keeping its `String` arg type non-nullable. **If non-null**, reads `myAssignedTasksProvider(uid)`. AppBar title comes from `context.strings.tasks.myTasksAppBarTitle` — no hardcoded literals.
9. New provider `myAssignedTasksProvider` in `lib/app/features/tasks/application/my_assigned_tasks_provider.dart`. Signature: `final myAssignedTasksProvider = Provider.family<AsyncValue<List<MyAssignedTaskRow>>, String>((ref, uid) { ... });`. Composes existing providers — **does NOT call any repo method directly** so lifecycle stays on the existing `disposeMirror` hooks:
    - `ref.watch(dashboardEventsProvider)` → the canonical events `AsyncValue<List<EventModel>>`.
    - For each event in the latest emission, `ref.watch(taskListProvider(event.id))` → per-event `AsyncValue<List<TaskModel>>`. `taskListProvider`'s `ref.onDispose(() => repo.disposeMirror(eventId))` already handles cleanup when this provider is disposed.
    - Flatten: filter each event's tasks to `assigneeId == uid`, map to `MyAssignedTaskRow(task: t, event: e)`, concatenate, return `AsyncValue.data(rows)`. If any input is `AsyncValue.loading`, return `AsyncValue.loading()`. If any is `AsyncValue.error`, return `AsyncValue.error(...)`.
10. Sole row type is `MyAssignedTaskRow` — a plain immutable Dart class with two `final` fields: `final TaskModel task; final EventModel event;`. Lives in the provider file. There is no Drift row type and no DAO change. The existing `TaskChecklistItemsDao.itemsByTaskIds` join (Phase 3) already populates `TaskModel.checklistItems` through `taskListProvider`, so the rows arrive complete.
11. `MyTasksScreen` renders, when the data list is non-empty: a `ListView` grouped by event. Each group has a `TasksGroupHeader` (event title, sage thin divider) followed by `TaskTile`s. Tile `onTap` calls `context.push('/dashboard/event/${row.event.id}/tasks/${row.task.id}')`. Each tile passes `currencyCode: row.event.currency`.
11a. While `myAssignedTasksProvider(uid)` is `AsyncValue.loading` (cold start / hot-restart before either `dashboardEventsProvider` or any inner `taskListProvider` has emitted), `MyTasksScreen` renders the existing `LoadingAnimation` widget centered. Once data has emitted at least once, the screen switches to the empty-state-or-list branch and never returns to the loading view (Riverpod retains the last `data` value across re-fetches).
11b. Phase 5's `_GroupHeader` (private inside `task_list_screen.dart`) is **extracted** to a shared `lib/app/features/tasks/presentation/widgets/tasks_group_header.dart` exporting `TasksGroupHeader(label: String, key: Key?)`. Both `task_list_screen.dart` and the new `my_tasks_screen.dart` consume the shared widget; the private `_GroupHeader` is deleted from `task_list_screen.dart`.
12. When the list is empty (data emitted, zero rows), `MyTasksScreen` renders `EmptyStatePlaceholder` with `title = TasksStrings.myTasksEmptyTitle`. Subtitle + CTA adapt to event count (see edge case 23 below): with events → `subtitle = TasksStrings.myTasksEmptySubtitle`, `ctaLabel = TasksStrings.openDashboardCta`. Without events → `subtitle = TasksStrings.myTasksEmptySubtitleNoEvents`, `ctaLabel = TasksStrings.createFromDashboardCta`. Both CTAs fire `() => context.go(AppRoutes.dashboard)` — `StatefulShellRoute.indexedStack` matches that path to the Dashboard branch and switches the active tab (does NOT stack a new route).

**Functional — Chat + Budget tab stubs:**

13. New file `lib/app/features/chat/presentation/chat_tab_placeholder_screen.dart`. `StatelessWidget`. AppBar title "Chat". Body = `EmptyStatePlaceholder` with `title = ChatStrings.tabEmptyTitle`, `subtitle = ChatStrings.tabEmptySubtitle`, `ctaLabel = TasksStrings.openDashboardCta` (reused), `onCta = () => context.go(AppRoutes.dashboard)`. (If there's no `ChatStrings` sub-object today, add one with two fields.)
14. New file `lib/app/features/budget/presentation/budget_tab_placeholder_screen.dart`. Same shape as the chat stub. Add `BudgetStrings` sub-object if needed.
15. `lib/app/core/router/app_router.dart` — drop the three `_PlaceholderScreen(title: ...)` lines (Tasks/Chat/Budget branches); replace with `const MyTasksScreen()`, `const ChatTabPlaceholderScreen()`, `const BudgetTabPlaceholderScreen()`. Remove the now-dead `_PlaceholderScreen` class.

**Functional — Migration of existing empty states:**

16. `lib/app/features/dashboard/presentation/dashboard_screen.dart` — replace the private `_EmptyState` class with a `EmptyStatePlaceholder` call. Title `DashboardStrings.noEventsTitle` ("No events yet"), subtitle `DashboardStrings.noEventsSubtitle` ("Create an event or join one with a code"), `ctaLabel = DashboardStrings.joinWithCode` ("Join with Code"), `onCta = () => JoinEventSheet.show(context: context)`. (Add `DashboardStrings` sub-object if it doesn't exist.)
17. `lib/app/features/tasks/presentation/task_list_screen.dart` — replace the private `_EmptyState` with `EmptyStatePlaceholder`. Two cases driven by `filter.hasActiveFilters`:
    - Active filters: `title = TasksStrings.emptyNoMatch` (already exists), `subtitle` unused, `ctaLabel = TasksStrings.clearFilters` (already exists), `onCta` resets the filter. The CTA button **must** retain `Key('tasks.list.emptyState.clear')` so existing tests + robots stay green. Add this key as a passthrough on `EmptyStatePlaceholder.cta` — see requirement 7's `emptyState.cta` key (the migrated screen wraps the `EmptyStatePlaceholder` in a `KeyedSubtree(key: const Key('tasks.list.emptyState'), ...)` to preserve the outer key contract).
    - No filters: `title = TasksStrings.emptyNoTasksYet` (already exists), `subtitle = TasksStrings.emptyNoTasksHelp` ("Tap + to create your first task" — new). No CTA.

**Functional — i18n:**

18. `lib/app/core/i18n/app_strings.dart` — extend `TasksStrings` + `_EnglishTasksStrings` with: `myTasksAppBarTitle`, `myTasksEmptyTitle`, `myTasksEmptySubtitle`, `myTasksEmptySubtitleNoEvents`, `openDashboardCta`, `createFromDashboardCta`, `emptyNoTasksHelp`, `signInRequiredTitle`. New sub-objects `ChatStrings` (`tabEmptyTitle`, `tabEmptySubtitle`) and `BudgetStrings` (`tabEmptyTitle`, `tabEmptySubtitle`) added as peers of `TasksStrings`. New `DashboardStrings` (`noEventsTitle`, `noEventsSubtitle`, `joinWithCode`) ditto. Wire each into `AppStrings` getters + `_EnglishStrings` impl.

**Error Handling:**

19. Lottie load failure → `errorBuilder` renders the icon fallback. `developer.log('Lottie asset failed: $lottieAsset', name: 'empty-state')` exactly once per asset path (static set dedupe). No user-visible error UI.
20. `myAssignedTasksProvider` errors (e.g., `eventRepositoryProvider.watchEventsForUser(uid)` throws) → the `MyTasksScreen` consumes the `AsyncValue` `.when` with an `error: (e, st) => EmptyStatePlaceholder(title: 'Could not load tasks', subtitle: e.toString(), lottieAsset: 'assets/animations/error.json')`. Log to `developer.log(name: 'tasks.myTasks')`.
21. `currentUserIdProvider` returns null (unauthenticated render race) → `MyTasksScreen` short-circuits per requirement 8 and renders `EmptyStatePlaceholder(title: TasksStrings.signInRequiredTitle)` with no CTA. The family provider is never invoked, which keeps `myAssignedTasksProvider.family<…, String>` non-nullable. Should not happen in practice (the auth gate keeps users out before the tab loads), but defensive.

**Edge Cases:**

22. User has events but no tasks assigned to them → `MyTasksScreen` empty state with `subtitle = TasksStrings.myTasksEmptySubtitle` ("Open an event from the Dashboard to view or create tasks.").
23. User has zero events → same empty state but subtitle becomes `TasksStrings.myTasksEmptySubtitleNoEvents` ("Create an event from the Dashboard to get started.") and CTA label becomes `TasksStrings.createFromDashboardCta` ("Create an event"). The provider yields `[]` for both cases; the screen consults `eventCount` (derived from `eventRepositoryProvider.watchEventsForUser`) to pick the copy.
24. Cross-event list with 1 event has only 1 group; rendering still uses the group header so the visual is consistent.
25. A task whose `assigneeId` was the current user but the user has since left the event → it shouldn't appear in the list because `watchEventsForUser(uid)` only returns events the user is a member of. The DAO's `event_id IN (:eventIds)` filter strips it.
26. Lottie animation file present but corrupted bytes → `errorBuilder` triggers; icon fallback renders. No app crash.
27. Multi-tab navigation: tapping the Open Dashboard CTA must use `context.go(AppRoutes.dashboard)` (bottom-nav switch) not `context.push(...)` (which would stack the dashboard on top of the Tasks tab).

**Validation:**

28. All new copy must route through `app_strings.dart`. No string literals in the widget files for user-visible text. (Architectural rule; trivial to grep-enforce.)
29. `EmptyStatePlaceholder` MUST not import Riverpod. It's a pure presentation widget — callers (`MyTasksScreen`, `_EmptyState`-migrated screens) own the wiring.
30. The deprecated key `tasks.list.emptyState.clear` MUST keep working for existing tests + `TasksRobot.expectEmptyState` (which currently looks up `tasks.list.emptyState`). The migration wraps `EmptyStatePlaceholder` in a `KeyedSubtree` carrying that outer key.

</requirements>

<boundaries>

**Edge cases:**

- **`assets/animations/empty_state.json` is the only animation rendered by `EmptyStatePlaceholder` by default.** The widget supports `lottieAsset` overrides so error / loading / success surfaces can reuse the same shape — but only with explicit caller intent. No "smart picker" that infers the animation from context.
- **Lottie file size sanity** — the default empty_state.json is small enough that hot-restart in debug isn't a concern. If a future asset is large (>500 KB), revisit whether to lazy-load it. Out of scope for V1.
- **Mounting + tab switching** — tapping the Open Dashboard CTA uses `context.go(...)` to switch the indexed-shell tab, not push a route. Tests that pump the screen without a `StatefulShellRoute` ancestor must inject a `goRouter` fake or simply pass an `onCta` that the test asserts.
- **Cross-event provider memory** — for each event the user is a member of, `myAssignedTasksProvider` spawns a `watchTasksByEventId(event.id)` subscription. If the user is in 50 events that's 50 Firestore listeners + 50 Drift watches. Acceptable for V1 because the existing per-event subscription is idempotent (`_ensureFirestoreMirror` checks `_firestoreSubs.containsKey(eventId)`). Document the soft cap of ~50 events in the spec; revisit if real-world data exceeds it.
- **`MyTasksScreen` doesn't include the Phase 5 filter bar.** That bar is event-scoped (currency, member names per event). Cross-event filtering is out of scope; the user picked the simple list.

**Error scenarios:**

- **Lottie asset path resolution** — `pubspec.yaml`'s `flutter.assets` block already declares `assets/animations/` as a directory, so any `.json` file dropped into that folder is auto-picked-up with no pubspec edit. A pubspec edit is ONLY needed when a caller adds a NEW directory (e.g. `assets/lotties/empty/`). If a caller's `lottieAsset` path can't be resolved at runtime, `Lottie.asset` surfaces the error to `errorBuilder`, the icon fallback renders, and `developer.log(name: 'empty-state')` warns once.
- **`watchEventsForUser` emits empty briefly during cold start** — `MyTasksScreen` shows the empty-state with "Create an event" copy. That's fine — it's accurate. Once the stream emits real data, the screen rebuilds with the list.
- **A Drift event row exists but the Firestore mirror hasn't caught up** — the tasks list may temporarily reference a stale event title. Acceptable; the next mirror snapshot fixes it.

**Limits:**

- **No hard cap on per-user event count**. The cross-event provider opens one `taskListProvider(eventId)` subscription per event the user belongs to; each subscription is idempotent (`_ensureFirestoreMirror` checks before opening). Revisit when a real user crosses ~25 events — at that point a server-side `collectionGroup` query becomes the obvious fix (spec'd in `<background>` as deferred). Until profiling proves a problem, the listener fan-out is acceptable.
- **TaskTile budget chip** — uses each task's event's `currency`. The cross-event list passes per-row `event.currency` to each `TaskTile`, so a task from a USD event and one from a EUR event render correctly side-by-side.
- **No pagination on `MyTasksScreen`** — `ListView` over `myAssignedTasksProvider` data. Acceptable; if users routinely have hundreds of assigned tasks, revisit. Spec'd as out-of-scope.

</boundaries>

<implementation>

**Files to create:**

- `lib/app/core/widgets/empty_state_placeholder.dart` — the shared widget.
- `lib/app/features/tasks/application/my_assigned_tasks_provider.dart` — `myAssignedTasksProvider` + `MyAssignedTaskRow` value class. No DAO changes.
- `lib/app/features/tasks/presentation/my_tasks_screen.dart` — the cross-event tasks tab.
- `lib/app/features/tasks/presentation/widgets/tasks_group_header.dart` — `TasksGroupHeader` widget extracted from Phase 5's private `_GroupHeader`. Consumed by both `task_list_screen.dart` and `my_tasks_screen.dart`.
- `lib/app/features/chat/presentation/chat_tab_placeholder_screen.dart` — chat tab stub.
- `lib/app/features/budget/presentation/budget_tab_placeholder_screen.dart` — budget tab stub.
- `test/app/core/widgets/empty_state_placeholder_test.dart` — widget tests for the shared widget.
- `test/app/features/tasks/my_assigned_tasks_provider_test.dart` — pure logic test for the cross-event aggregation, using Riverpod overrides on `dashboardEventsProvider` and `taskListProvider`.
- `test/app/features/tasks/my_tasks_screen_test.dart` — widget tests for the new tab (loading / empty-with-events / empty-no-events / non-empty / null uid).
- `test/journeys/tasks_tab_empty_state_journey_test.dart` — see Validation block for the explicit scope; either screen-only (capture CTA) OR full `StatefulShellRoute` harness.

**Files to modify:**

- `lib/app/core/router/app_router.dart` — replace three `_PlaceholderScreen(title: '...')` with the new tab screens; delete the now-dead `_PlaceholderScreen` class.
- `lib/app/core/i18n/app_strings.dart` — extend `TasksStrings`; add `ChatStrings` / `BudgetStrings` / `DashboardStrings` sub-objects + English impls; wire into `AppStrings`.
- `lib/app/features/dashboard/presentation/dashboard_screen.dart` — replace `_EmptyState` body with `EmptyStatePlaceholder` (delete the class).
- `lib/app/features/tasks/presentation/task_list_screen.dart` — replace the private `_EmptyState` with `EmptyStatePlaceholder` (using `ctaKey: const Key('tasks.list.emptyState.clear')` for the Clear-filters case); wrap the empty state in a `KeyedSubtree(key: const Key('tasks.list.emptyState'))` so the outer Phase 5 key contract survives. Delete the private `_GroupHeader` and switch its usage to the new shared `TasksGroupHeader`.

**Patterns to use:**

- `EmptyStatePlaceholder` is `StatelessWidget`. No `FocusNode`, no `Riverpod`, no `clock` — pure presentation.
- The cross-event provider uses the existing `eventRepositoryProvider` + `taskRepositoryProvider`. Do NOT cast around through globals; thread `ref` through cleanly.
- `developer.log` for diagnostics (consistent with `task_repository.dart` and `event_repository.dart`). No `print` calls.
- The provider composes Riverpod streams only — no new Drift row class, no new DAO method. `MyAssignedTaskRow` is a plain Dart class holding the full `TaskModel` and the full `EventModel`, so the screen has everything it needs (event title, event currency, etc.) without a second lookup.
- For the migrated `task_list_screen` empty-state migration: wrap `EmptyStatePlaceholder` in `KeyedSubtree(key: const Key('tasks.list.emptyState'))` and pass `Key('tasks.list.emptyState.clear')` to the CTA via a new optional `ctaKey` param on `EmptyStatePlaceholder`. Adding `ctaKey: Key?` is preferable to forcing every caller to wrap — and keeps Phase 5 tests passing.

**What to avoid:**

- No new pub packages. Lottie is already in `pubspec.yaml`; everything else is in core Flutter or already used.
- Don't introduce a server-side `collectionGroup` query — out of scope, requires rules + index changes that are bigger than this PR.
- Don't centralise the `myAssignedTasksProvider` listener-fan-out via Cloud Functions. Spec'd as deferred.
- Don't migrate the per-tile `TaskTile` to take `EventModel` instead of `currencyCode` — keep the existing API contract; `MyTasksScreen` will pass `currencyCode: row.event.currency` per tile.
- Don't add new lottie animations to `assets/animations/` in this PR; reuse the existing `empty_state.json` everywhere by default. Future PRs can add `tasks_empty.json`, `chat_empty.json`, etc., and pass them via `lottieAsset`.

</implementation>

<validation>

**Required automated coverage outcomes** (each item must be a passing test before merge):

- **Unit tests — pure logic:**
  - `myAssignedTasksProvider` composition: override `dashboardEventsProvider` to emit two events, override each `taskListProvider(eventId)` family entry to emit a fixed task list mixing assigneeIds. Assert the provider's `AsyncValue.data` contains only rows where `task.assigneeId == uid`, each row's `event` matches its task's `eventId`, and ordering is deterministic (events in dashboard order; tasks within an event in their original list order).
  - Loading propagation: when ANY input is `AsyncValue.loading`, the provider returns `AsyncValue.loading()`. When ALL inputs are `data`, it returns `data`.
  - Error propagation: when `dashboardEventsProvider` errors, the provider returns `AsyncValue.error(...)`. Same for any inner `taskListProvider`.
  - `assigneeId` filter excludes tasks belonging to other users even when those tasks share an event with the current user.

- **Widget tests — `EmptyStatePlaceholder`:**
  - Renders title + subtitle + CTA when all are provided; assertions via `emptyState.title` / `emptyState.subtitle` / `emptyState.cta` keys.
  - CTA tap fires the `onCta` callback.
  - When `ctaLabel` or `onCta` is null, no button renders.
  - When `lottieAsset` is supplied a path that doesn't exist, the `errorBuilder` renders the icon-fallback widget. **The fallback fires asynchronously** — the test MUST pump at least 3 frames of 50 ms (`for (var i = 0; i < 3; i++) await tester.pump(const Duration(milliseconds: 50));`) before asserting `emptyState.iconFallback`. **Do NOT use `pumpAndSettle`** — the lottie animation loops forever and `pumpAndSettle` will time out.
  - `ctaKey` passthrough — when supplied via `ctaKey: const Key('foo')`, the rendered `OutlinedButton` is found by that key. Default `emptyState.cta` key is still present.

- **Widget tests — migrated empty states:**
  - `task_list_screen` keeps `Key('tasks.list.emptyState')` + `Key('tasks.list.emptyState.clear')` working (existing Phase 5 tests must pass without modification).
  - `dashboard_screen` no-events empty state still renders "No events yet" copy + the Join button still opens `JoinEventSheet` (use a faked `Navigator` or just assert the button key).

- **Widget tests — `MyTasksScreen`:**
  - **Loading**: when `myAssignedTasksProvider` overridden to `AsyncValue.loading()`, the screen renders `LoadingAnimation` and no empty state / list.
  - **Empty list with events**: data is `[]` and `dashboardEventsProvider` has ≥ 1 event → renders `EmptyStatePlaceholder` with `myTasksEmptySubtitle` + `openDashboardCta`. CTA key fires the callback.
  - **Empty list without events**: data is `[]` and `dashboardEventsProvider` data is `[]` → CTA label is `createFromDashboardCta` (not `openDashboardCta`).
  - **Null uid**: `currentUserIdProvider` overridden to `null` → screen renders `EmptyStatePlaceholder(title: signInRequiredTitle)` with no CTA AND `myAssignedTasksProvider` is NEVER subscribed (assert via a counter wired into the override factory).
  - **Non-empty list**: data has rows across two distinct events → renders one `TasksGroupHeader` per event + a `TaskTile` per row. Tapping a tile fires the captured `context.push(...)` call (assert via a fake `GoRouter` or a test-injected push handler).

- **Robot journey test (`test/journeys/tasks_tab_empty_state_journey_test.dart`):**
  - **Scope** (pick one; spec'd explicitly to avoid hand-waving): use a screen-level harness that pumps `MyTasksScreen` directly inside a minimal `ProviderScope` + `MaterialApp`. Override `currentUserIdProvider` to a fixed uid, `dashboardEventsProvider` to `AsyncValue.data([])`, and capture the CTA tap by overriding the navigation seam (the screen exposes its `context.go(AppRoutes.dashboard)` call indirectly — the harness asserts the CTA `onCta` callback fired). A full `StatefulShellRoute` test harness (a real bottom-nav switching tabs) is **out of scope** for this PR; document it in `<background>` as a future "TabsJourneyHarness" piece.
  - Steps: pump screen → seed loading → seed `data: []` with zero events → pump 3 × 50 ms → assert `emptyState.title` + `emptyState.cta` visible; CTA label is the no-events variant.
  - Tap the CTA → assert the captured callback fired exactly once. (No real tab switch verified here.)

**TDD expectations** (per `flutter-tdd`):

- Build slices in order: pure DAO → pure provider → widget tests bottom-up (EmptyStatePlaceholder → MyTasksScreen → migrations) → robot journey. One failing test at a time per cycle.
- Required seams:
  - `Lottie.asset` failure path — drive via `lottieAsset` set to a non-existent path so the `errorBuilder` actually fires. The widget is `StatelessWidget`; no internal mocking needed.
  - `myAssignedTasksProvider` accepts `Stream<List<EventModel>> Function(String)` and `Stream<List<TaskModel>> Function(String)` constructor-injected hooks via providers (don't reach for globals). Tests override the providers.
  - `currentUserIdProvider` Riverpod override for test determinism.
  - `JoinEventSheet.show` — in the dashboard empty-state widget test, override the CTA callback to capture instead of opening the bottom sheet (the sheet's render is tested elsewhere).
- Mocking policy: prefer Riverpod overrides + `fake_cloud_firestore` (already in `dev_dependencies`). Mock only at the `eventRepositoryProvider` / `taskRepositoryProvider` boundary if needed.
- Justified exceptions: lottie rendering correctness (animation playback) is NOT tested; we trust the lottie package. The `errorBuilder` IS tested.

**Robot testing baseline** (per `flutter-robot-testing`):

- Stable selectors required (already specified in requirements 7 + 30):
  - `emptyState.title`, `emptyState.subtitle`, `emptyState.cta`, `emptyState.iconFallback`, `emptyState.lottie`
  - `tasks.list.emptyState`, `tasks.list.emptyState.clear` (preserved for back-compat)
- Robot helper for the new tab: extend `TasksRobot` (or add a new `TabRobot`) with `tapTasksTab()`, `tapDashboardTab()`, `expectMyTasksEmptyState()`.
- Deterministic seams: override the events provider to return a fixed-size list (0, 1, or N events) and the tasks provider per-event. No real Firestore in the journey.
- Known testing risks:
  - The bottom-nav `StatefulShellRoute` needs a real router in the harness. Reuse the existing `DashboardJourneyHarness` pattern (`test/harness/dashboard_harness.dart`) and add a small extension that pumps the full router shell. Document in the test header.
  - Lottie loading is async — pump enough frames (`tester.pump(Duration(milliseconds: 100))` × 3) to let the animation initialise. Don't `pumpAndSettle` (lottie loops forever).

**Manual smoke** (before declaring done):

- Cold-launch the app on a fresh user account → land on Auth → sign up → land on Dashboard → tap Tasks tab → see the EmptyStatePlaceholder with the lottie + "Create an event" CTA → tap CTA → ends back on Dashboard.
- Same with one event but no assigned tasks → Tasks tab shows "Open an event" copy.
- Assign a task to self in an event → Tasks tab now shows the task; tapping it opens the event-scoped detail screen.

</validation>

<done_when>

- `EmptyStatePlaceholder` is implemented per requirements 1–7 and 28–29, with widget tests covering all branches (CTA present/absent, lottie success/failure paths, `ctaKey` passthrough).
- `MyTasksScreen` + `myAssignedTasksProvider` ship per requirements 8–12 (plus 11a loading state, 11b shared `TasksGroupHeader`) and 21, 22, 23; aggregated list renders grouped by event using the shared `TasksGroupHeader`; loading shows `LoadingAnimation`; empty / zero-events copy adapts; null-uid short-circuits without invoking the family provider; tile taps navigate to the event-scoped task detail. Provider composes existing `dashboardEventsProvider` + `taskListProvider` only — no new DAO surface.
- Chat + Budget tabs render `EmptyStatePlaceholder` (requirements 13–14); the three `_PlaceholderScreen` rows in `app_router.dart` are gone (requirement 15) and the `_PlaceholderScreen` class is deleted.
- `dashboard_screen._EmptyState` and `task_list_screen._EmptyState` both delegate to `EmptyStatePlaceholder` (requirements 16–17, 30); the legacy `tasks.list.emptyState` + `tasks.list.emptyState.clear` keys keep working without test changes.
- `TasksStrings` / `ChatStrings` / `BudgetStrings` / `DashboardStrings` are extended; no hardcoded literals in any modified file (requirement 28 — confirmed by grep).
- `flutter analyze` clean (the pre-existing `TableMigration` experimental warning is the only allowed remainder).
- `flutter test` green; +N new tests across the `EmptyStatePlaceholder` widget (incl. ≥ 3 × 50 ms pumps for the lottie fallback assertion — no `pumpAndSettle`), `myAssignedTasksProvider` composition test, `MyTasksScreen` widget (loading + 4 empty/non-empty + null-uid branches), and the screen-level empty-state journey.
- All existing Phase 5 tasks-list tests pass unchanged (regression on the `emptyState` keys).
- Branch name suggestion: `tasks-tab-empty-state`. Off latest `main` after `task` merges (or branched from `task` if that hasn't merged yet — pick whichever is current).

</done_when>
