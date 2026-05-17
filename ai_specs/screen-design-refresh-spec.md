<goal>
Refresh the visual design and information density of CrewPoint's five primary tab screens — Dashboard (Events), Tasks, Chat, Budget, Profile — using existing wireframes in `docs/screen_wireframe/` as a baseline and layering on (a) task-stage progress visualization, (b) a cohesive reusable component layer, and (c) an enforced "any age" accessibility floor.

The outcome users experience:
- Each event card and the Tasks header show a small progress ring with todo / doing / done counts, so a 12-year-old or a 70-year-old can read "where are we?" at a glance without parsing a task list.
- Every screen looks like it was designed by the same person on the same day — shared cards, chips, headers, empty states, and status badges.
- Tap targets are ≥48dp, type scales up to 200%, every status uses icon + color (never color alone), and labels read like normal English ("You owe", "Waiting on you") not jargon.
- No data-model or routing changes — this is presentation and reusable widgets only.

Who benefits: every CrewPoint user, with explicit attention to first-time users, older users, and users with low vision or color blindness.
</goal>

<background>
**Tech stack (relevant):**
- Flutter (SDK ^3.11.5), Material 3, Riverpod 3, go_router 14, Drift for local data, Firestore for sync.
- Theming centralized in `lib/app/core/theme/app_theme.dart`; palette in `lib/app/core/constants/app_colors.dart`; typography in `lib/app/core/constants/app_typography.dart`; spacing in `lib/app/core/constants/app_spacing.dart`.
- 5-tab adaptive shell: `lib/app/core/widgets/responsive_shell.dart` (bottom NavigationBar < 840 px, NavigationRail ≥ 840 px). Tabs today: Dashboard, Tasks, Chat, Budget, Profile.

**Current screens to refresh:**
- @lib/app/features/dashboard/presentation/dashboard_screen.dart
- @lib/app/features/dashboard/presentation/widgets/event_card.dart
- @lib/app/features/tasks/presentation/my_tasks_screen.dart
- @lib/app/features/tasks/presentation/task_list_screen.dart
- @lib/app/features/chat/presentation/ (chat inbox screen)
- @lib/app/features/budget/presentation/ (budget overview screen)
- @lib/app/features/profile/presentation/ (profile screen)

**Wireframes (baseline; visual reference only — text/copy/spacing/contrast may be improved):**
- @docs/screen_wireframe/Dashboard.png
- @docs/screen_wireframe/Tasks.png
- @docs/screen_wireframe/Chat.png
- @docs/screen_wireframe/Budget.png
- @docs/screen_wireframe/Profile.png

**Existing primitives to reuse / extend:**
- @lib/app/core/widgets/empty_state_placeholder.dart
- @lib/app/core/widgets/primary_button.dart
- @lib/app/core/widgets/destructive_button.dart
- @lib/app/core/widgets/content_max_width.dart (clamps wide layouts to 720; new tiles must compose under this)
- @lib/app/core/widgets/network_image_with_placeholder.dart (initials fallback for avatars already implemented)
- @lib/app/core/widgets/loading_animation.dart (Lottie loader — used everywhere)
- `Breakpoints.screenHorizontalPadding(context)` — canonical responsive horizontal padding.

**Existing screen-level widgets touched by this refresh (replacement matrix):**

| Existing widget / file | Disposition in this spec |
| --- | --- |
| `EventCard` (dashboard/.../widgets/event_card.dart) | Contents rewritten to render the new `EventTile`. File path preserved so existing imports keep working. |
| `LedgerHeroStrip` (budget/.../widgets/) | Replaced by `BalanceTile`. Multi-currency disclaimer behaviour migrates. |
| `DebtTile` (budget/.../widgets/debt_tile.dart) | **Kept as-is.** Already integrates `settleUpControllerProvider`. The new `DebtRow` is dropped from the spec; `DebtTile` IS the row. |
| `RecentExpenseTile` (budget/.../widgets/) | Kept as-is for now. Visual polish only (token colors). |
| `InboxTile` (chat/.../widgets/inbox_tile.dart) | Replaced by `ConversationTile`. |
| `TaskTile` (tasks/.../widgets/task_tile.dart) | **Kept as-is.** Status chip + checklist progress bar already use icon+color and work. Only its currency formatter is retrofitted to `MoneyText`. |
| `TasksFilterBar` (tasks/.../widgets/tasks_filter_bar.dart) | **Kept as-is** on `EventTasksPage`. The new `SegmentedFilterBar` is for the global `MyTasksScreen` only. The two coexist; this spec does not unify them. |
| `TasksGroupHeader` (tasks/.../widgets/) | Replaced by the new `SectionLabel`. |
| Private widgets in `profile_screen.dart` (`_HeroCard`, `_SectionHeader`, `_SectionCard`, `_SettingsTile`, `_PaymentCard`, `_DangerCard`, `_AppVersion`) | `_SectionHeader` → `SectionLabel`. `_SectionCard` → kept inline. `_SettingsTile` → `SettingsRow`. `_HeroCard` → **kept** (the existing gradient hero is preserved; `StatTriplet` is inserted between hero and SETTINGS). `_PaymentCard`, `_DangerCard`, `_AppVersion` → unchanged. |

**Existing domain (no changes needed):**
- `TaskStatus` enum already has `todo`, `inProgress`, `done` — see @lib/app/features/tasks/domain/models/task.dart:138. All three are user-writable today via `TaskTile._StatusChip` (task_tile.dart:174-199), which cycles `todo → inProgress → done → todo` on tap. The ring consumes real three-arc data.
- Budget tiles (`DebtTile` + Settle Up controller) are wired from Phase 4 (commit `110a038`).
- Chat inbox unread + urgent indicators exist from Phase 2 (commit `1cdb315`).
- `clock: ^1.1.1` is already in pubspec and used by `TaskTile` for overdue detection — the new time-of-day greeting reuses the same `clock.now()` seam.

**Constraints:**
- Do NOT modify domain models, repositories, services, or routes. Spec is presentation + reusable widgets only.
- ONE new application-layer provider is in scope: a Drift-backed `eventTaskCountsProvider(eventId)` returning `{todo, doing, done}` counts derived from the local `tasks` table — no Firestore reads added.
- Do NOT introduce a new design package, theme override, or competing color system. Extend `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, and `AppTheme` in place.
- **Bottom nav rename is mandatory**: both the *key* (`shell.bar.dashboard` → `shell.bar.home`, `shell.rail.dashboard` → `shell.rail.home`) and the *label* ("Dashboard" → "Home") change in the same commit. Every test fixture that references the old key or label must be updated in the same change. Route paths (`/dashboard`) and the existing widget keys on Dashboard's body (`Key('dashboard.events.list')`, `Key('dashboard.body.clamped')`) are preserved.
- All new widgets land flat under `lib/app/core/widgets/` — match the existing convention; no `design_system/` subfolder.
- Light theme is the priority; dark theme parity is required but a minimal pass (parity, not separate visuals).
- `EmailUnverifiedBanner` continues to render at the top of every shell branch (app_router.dart:123-126). `ScreenHeader` renders below it and must not claim the top safe-area inset.
</background>

<design_tokens>
Add the following semantic tokens. Names are illustrative; final names are at the implementor's discretion provided they are stable and exported from one place.

**Status semantic colors** (light mode) — extend `AppColors`:
- `statusTodoFg` — neutral grey-blue, for "not started" icon + text (must hit ≥4.5:1 on `offWhite` and `white`).
- `statusTodoBg` — soft tint of the same.
- `statusDoingFg` — accent (warm gold or terracotta-light); ≥4.5:1 on light surfaces.
- `statusDoingBg` — soft tint.
- `statusDoneFg` — `sageDark` (already AA-safe on white per existing audit note).
- `statusDoneBg` — soft sage tint.
- `statusUrgentFg` — `terracottaDark`.
- `statusUrgentBg` — soft terracotta tint.

**Money semantic colors** (already present; document the mapping):
- `moneyOwedToYouFg` = `sageDark` (you are owed → positive)
- `moneyYouOweFg` = `terracottaDark` (you owe → attention)

**Typography scale additions** (extend `AppTypography`):
- Bump body default from 14 → 16 px to clear "any age" floor.
- Add `numberDisplay` style (large, tabular figures) for Profile stats and Budget balance numbers.
- All styles must round-trip through Material text theme so OS dynamic-type scaling (`MediaQuery.textScaler`) reaches them.

**Spacing additions** (extend `AppSpacing`) — only if a needed value is missing today. Prefer reuse.

All tokens must be referenced from one place only. No hex literals in screen files.
</design_tokens>

<component_library>
Create these reusable widgets flat under `lib/app/core/widgets/` (match existing convention; no subfolder). Each must be:
- Stateless where possible.
- Driven by parameters (no provider reads inside the widget itself; widgets are pure UI).
- Covered by at least one widget test.

1. **`StatusBadge`** — small chip with leading icon + label + optional count.
   - Variants: `todo`, `doing`, `done`, `urgent`, `info`.
   - Each variant pairs a fixed icon (`Icons.radio_button_unchecked`, `Icons.play_circle_outline`, `Icons.check_circle`, `Icons.warning_amber_rounded`, `Icons.info_outline`) with the matching semantic color from `design_tokens`.
   - Used on event cards, task rows (status pill), chat row (urgent badge), tasks header (per-status counts).

2. **`ProgressRing`** — small circular indicator (default 36 dp, configurable).
   - Renders three arcs: done (filled), doing (filled, lighter), todo (track).
   - Centered label shows "{done}/{total}" by default; can also show a percent.
   - Accessible: announces "X of Y tasks complete, Z in progress" to screen readers.
   - When `total == 0`, renders a neutral empty ring with a "—" label (no division by zero).

3. **`TaskProgressSummary`** — combo widget: `ProgressRing` + a row of three `StatusBadge`s (todo/doing/done with counts). Used in event cards (compact: ring only by default; chips visible on the wider tablet/rail layout) and at the top of the Tasks screen filter strip.

4. **`ScreenHeader`** — large title + optional subtitle/timestamp + optional trailing action(s). Replaces ad-hoc `AppBar` titles where the wireframes show "Tasks", "Messages", "Budget", "Profile", "Good morning, Alex 👋" patterns.

5. **`SectionLabel`** — uppercase, letter-spaced micro-label (e.g., "2 UPCOMING EVENTS", "BREAKDOWN", "SETTINGS"). One canonical style.

6. **`EventTile`** — card with: type emoji (derived from `EventType` via map below), title, date range, member count badge ("3 members"), `TaskProgressSummary` (compact: ring only on mobile; ring + chips on rail), trailing "View Details ›". **Out of scope for this spec:** per-member avatar stack (requires a new batch users-by-uid provider) and per-event money chip (requires per-event expense subscription). These are noted as follow-ups.

   `EventType → emoji` map (canonical, exported from `event_type_emoji.dart`):
   - `EventType.trip` → 🏔️
   - `EventType.project` → 📋
   - `EventType.social` → 🎉
   - `EventType.custom` → 📌

7. **`ConversationTile`** — chat inbox row: event-type emoji (same map), event title, preview line ("{Sender}: {message}"), timestamp, urgent badge (`StatusBadge.urgent`), unread count pill. Replaces `InboxTile`.

8. **`BalanceTile`** — Budget summary card: split layout "You are owed $X | You owe $Y" with a thin horizontal split bar visualizing the ratio. Numbers use `numberDisplay` style with tabular figures so digits don't shift width. Multi-currency disclaimer banner migrates from `LedgerHeroStrip`.

9. **`SettingsRow`** — icon + title + subtitle + trailing chevron. Replaces the private `_SettingsTile` in `profile_screen.dart`.

10. **`StatTriplet`** — three centered "{value} / {label}" cells separated by thin dividers, used on Profile ("4 Events / 12 Tasks / $150 Owed"). Inserted between the existing gradient `_HeroCard` and the SETTINGS section — the gradient hero is preserved.

11. **`SegmentedFilterBar`** — pill-style single-select segmented control. Used by:
    - Dashboard: `Upcoming | Past`
    - MyTasksScreen (global Tasks tab): `All | Todo | Doing | Done`, with a separate "Overdue" toggle rendered alongside (not inside the segmented pill).
    Active pill uses `charcoal` background + white label; inactive pills are surface with charcoal text. The "Overdue" toggle is a separate `FilterChip`-style pill that uses `statusUrgentFg` text + tint when count > 0. **Does NOT replace** the multi-select `TasksFilterBar` on `EventTasksPage`.

12. **`MoneyText`** — formats a currency amount with the event's / user's currency setting and applies a semantic color based on a `MoneySign` enum (`owedToYou` | `youOwe` | `neutral`). **Retrofit required:** existing call sites that format currency via `NumberFormat.simpleCurrency` are migrated to `MoneyText` in this spec — `TaskTile` (task_tile.dart:153), `DebtTile`, `RecentExpenseTile`, `LedgerHeroStrip` (when collapsed into `BalanceTile`). Centralized formatting prevents drift.

13. **`EmptyStatePlaceholder`** (already exists) — reuse as-is; no API extension needed.

14. **Skeleton placeholders (`skeletons.dart`)** — net-new lightweight shimmer placeholders matching the final layout of `EventTile`, `ConversationTile`, `BalanceTile + DebtTile`, and `MyTasksScreen` rows. Renders during provider `loading` states in place of the current centered `LoadingAnimation` (Lottie). Lottie loader is retained as a fallback for full-screen empty/error animations.
</component_library>

<user_flows>

**Dashboard (Home) — primary flow:**
1. User opens app → lands on Home tab.
2. Sees personalized header (`ScreenHeader`): "{Time-of-day greeting}, {FirstName} 👋" + today's date. **Trailing action:** Join Event icon (preserves the existing `JoinEventSheet` entry point — that flow does not move).
   - **Greeting name:** `displayName.split(' ').first` when `displayName` is non-empty; otherwise "there".
   - **Time-of-day boundaries** (via `clock.now()`): morning < 12:00, afternoon < 17:00, evening otherwise.
3. Segmented filter (`SegmentedFilterBar`): `Upcoming` (default) / `Past`. Partition by `event.endDate ?? event.startDate` vs `clock.now()`: events with no end-date AND no start-date stay in `Upcoming`.
4. Section label: "{N} UPCOMING EVENTS" / "{N} PAST EVENTS".
5. List of `EventTile` cards. Each shows: `EventType` emoji, title, date range, member count badge (e.g., "3 members"), compact `TaskProgressSummary` (ring + done/total label), trailing "View Details ›".
6. Prominent "+ Create Event" button above the list (per wireframe). The existing FAB (`dashboard_screen.dart:79`) is removed — its function is now the inline button.
7. Per-event avatar stacks and per-event money chips are **out of scope** for this spec — they would require new providers and are noted as follow-ups.

**Dashboard alternative flows:**
- **No events:** existing `EmptyStatePlaceholder` with title, subtitle, and dual CTAs (Create Event + Join with Code).
- **Past tab selected:** same tile design; section label reads "{N} PAST EVENTS"; progress ring still rendered but visually muted (use `statusDoneBg` track to communicate "wrapped up"). Money chip remains visible if any debts unresolved.
- **Rail (≥ 840 px) layout:** Event tiles expand to show the full `TaskProgressSummary` (ring + three count chips) instead of ring only.

**Dashboard error flow:**
- Provider error → centered message + retry button (today the screen has the message but no retry). Add a labeled "Try again" button that re-watches the provider.

---

**Tasks — primary flow:**
The bottom-tab Tasks screen is the existing `MyTasksScreen`, which is **scoped to "tasks assigned to the current user"** via `myAssignedTasksProvider(uid)` (lib/app/features/tasks/presentation/my_tasks_screen.dart:27). This spec keeps that scope. The wireframe's `All / Overdue / Mine / Completed` pills are reinterpreted to match real data — see below.

1. User taps Tasks tab.
2. Sees `ScreenHeader` ("My Tasks"). **No search field is added in this spec** — search lives on `EventTasksPage` (already implemented via `TasksFilterBar`); promoting it to the global tab is deferred.
3. `TaskProgressSummary` strip below header: ring + chips showing the user's *own* task counts across all events, derived client-side from the already-watched `myAssignedTasksProvider` list — no new subscription.
4. Filter row:
   - `SegmentedFilterBar` (single-select): `All` (default) / `Todo` / `Doing` / `Done`.
   - Separate `Overdue` toggle pill rendered to the right, with urgent count badge when > 0. Mutually compatible with the segmented filter (e.g., `Doing + Overdue` is a valid intersection).
5. Tasks grouped by event using `SectionLabel` (event-type emoji + event title). The existing `TasksGroupHeader` is replaced.
6. Each task row uses the existing `TaskTile` (kept as-is — its status chip already cycles todo/inProgress/done with icon+color, and its checklist progress bar is already present). Only its currency formatter is retrofitted to `MoneyText`.
7. Tapping a task → existing task detail route (no change).

**Tasks alternative flows:**
- **`Done` filter:** rows render with the existing strikethrough already implemented in `TaskTile`. Tapping the status chip cycles back to `todo` per existing behaviour.
- **Empty state (no matches for filter):** `EmptyStatePlaceholder` with filter-aware copy. The existing adaptive empty state (`_MyTasksEmptyState` at my_tasks_screen.dart:157) is reused; this spec adds a "no tasks match this filter" variant when the user has tasks but none satisfy the active filter.
- **No tasks at all:** existing copy already directs user to event creation; reuse.

**Tasks error flow:**
- Same retry pattern as Dashboard.

---

**Chat — primary flow:**
1. User taps Chat tab.
2. Sees `ScreenHeader` ("Messages") + search field.
3. List of `ConversationTile` rows ordered by activity recency.
4. Each row: event emoji/cover, event title, last-message preview ("{Sender}: {message}"), relative timestamp ("2m ago", "Yesterday"), unread count pill (when > 0), `StatusBadge.urgent` (when an urgent message is unread).
5. Tapping → existing thread route.

**Chat alternative flows:**
- **All threads read, no urgent:** rows show no pill or badge. Timestamp stays.
- **Empty:** no threads → empty state pointing user to create or join an event.

---

**Budget — primary flow:**
1. User taps Budget tab.
2. Sees `ScreenHeader` ("Budget").
3. `BalanceTile`: "You are owed $150.00 | You owe $45.00" with horizontal split bar visualizing the ratio. If both are zero: bar collapses to a neutral "$0.00 all settled" state. Multi-currency disclaimer banner (from existing `LedgerHeroStrip`) is preserved.
4. `SectionLabel` "BREAKDOWN".
5. Stack of existing `DebtTile` widgets (kept as-is — they already integrate `settleUpControllerProvider`). Visual polish only: typography + semantic color tokens applied.
6. `SectionLabel` "RECENT EXPENSES" + existing `RecentExpenseTile`s preserved.
7. Tapping `Settle Up` on a `DebtTile` triggers the existing Phase 4 flow (deep link + fallback sheet from commit `110a038`).

**Budget alternative flows:**
- **Mixed direction:** each `DebtTile` independently signals "you owe" (terracotta) vs "owes you" (sage). Ratio bar uses both colors weighted by magnitude.
- **All settled:** `BalanceTile` shows zero; existing `LedgerAllSettledChip` is preserved.

---

**Profile — primary flow:**
The existing `_HeroCard` gradient (charcoal → charcoalDark with sage glow + Edit Profile pill) is **kept** — it's a deliberate aesthetic choice that diverges from the wireframe in a way the team prefers. This spec only adds the stat row beneath it.

1. User taps Profile tab.
2. Sees existing gradient `_HeroCard` (avatar + name + email + Edit Profile pill — unchanged).
3. **New:** `StatTriplet` inserted directly below the hero — Events count (from `dashboardEventsProvider`), Tasks count (from `myAssignedTasksProvider`), Owed amount (from `globalBalanceLedgerProvider.totalYouOwe` — labelled "Owed" with a sign that follows wireframe convention).
4. `SectionLabel` "SETTINGS" + existing settings rows refactored to `SettingsRow` (Privacy Dashboard + Notifications today).
5. `SectionLabel` "PAYMENT" + existing `_PaymentCard` preserved.
6. Sign Out outlined button (terracotta) — existing, preserved.
7. Danger Zone (Delete Account) — existing, preserved.
8. App version footer — existing, preserved.

**Profile alternative flows:**
- Each settings row taps to its existing sub-screen.
- Sign Out: existing `SignOutSheet` flow.
- Delete Account: existing `DeleteAccountDialog` flow.
- `StatTriplet` while data is loading: each cell shows "—" until its provider emits; no skeleton on Profile because the hero already provides above-the-fold content.

**Out of scope for this spec:** `EditProfileScreen`, `MarkdownRenderScreen`, `PrivacyDashboardScreen` redesigns. They keep their current layout.
</user_flows>

<requirements>

**Functional — design system foundation:**
1. Add semantic status & money color tokens to `AppColors`. Each value must pass WCAG AA contrast on every surface it appears on (`white`, `offWhite`, `cream`, dark `surfaceDarkElevated`). **Cream is the hardest case** — `app_theme.dart:24-27` documents that `onSurfaceVariant` already fails AA on cream (3.93:1); the "doing" semantic foreground must be measured on cream specifically and may need a darker variant. Document the measured contrast ratio in a comment beside each constant for each of the four surfaces.
2. Raise `AppTypography` default body size to 16 px and verify all existing usages still pass auto-layout (no overflows in `dashboard.body.clamped`, `profile.body.clamped`, or any `ContentMaxWidth(maxWidth: 720)` clamped container).
3. Add a `numberDisplay` text style using tabular figures so digits in `BalanceTile`, `StatTriplet`, and `MoneyText` don't shift width.
4. All new widgets in `<component_library>` are implemented flat under `lib/app/core/widgets/` — no `design_system/` subfolder, no barrel file.

**Functional — per screen:**
5. Dashboard: `ScreenHeader` shows time-of-day greeting + date + Join Event trailing action (preserving the existing `JoinEventSheet` entry point); inline "+ Create Event" button (FAB removed); segmented Upcoming/Past filter; events rendered via `EventTile` with `EventType` emoji + title + date range + "{N} members" badge + compact `TaskProgressSummary` ring.
6. Tasks (`MyTasksScreen`): `ScreenHeader` ("My Tasks") + `TaskProgressSummary` strip + `SegmentedFilterBar` (All / Todo / Doing / Done) + separate Overdue toggle with count badge; rows grouped by event via `SectionLabel`; rows render via existing `TaskTile` (kept; currency formatter retrofitted to `MoneyText`). **No search field added** — search remains on `EventTasksPage` via existing `TasksFilterBar`.
7. Chat: `ScreenHeader` ("Messages") + `ConversationTile` rows with urgent badge + unread pill. **No search field added** in this spec; deferred.
8. Budget: `ScreenHeader` ("Budget") + `BalanceTile` + `SectionLabel` "BREAKDOWN" + existing `DebtTile` list (kept; Phase 4 Settle Up flow preserved) + `SectionLabel` "RECENT EXPENSES" + existing `RecentExpenseTile` list (kept).
9. Profile: existing gradient `_HeroCard` preserved + new `StatTriplet` (Events / Tasks / Owed) inserted below + existing settings rows refactored to public `SettingsRow` + existing `_PaymentCard`, Sign Out button, Danger Zone, version footer all preserved.
10. Bottom nav (and rail) at index 0: both the *label* ("Dashboard" → "Home") and the *keys* (`shell.bar.dashboard` → `shell.bar.home`, `shell.rail.dashboard` → `shell.rail.home`) are renamed. Every test fixture referencing the old label or key is updated in the same change. Icons and route paths unchanged.

**Functional — task progress derivation:**
11. Progress counts derive from `TaskStatus`: `done` = `status == done`, `doing` = `status == inProgress`, `todo` = `status == todo`. All three are real, user-writable values today via `TaskTile._StatusChip` cycle (task_tile.dart:174-199).
12. Per-event progress on the Dashboard `EventTile` reads from a **new** application-layer provider, `eventTaskCountsProvider(eventId)`, backed by the existing Drift `tasks` table (`TasksDao`). Returns `{todo, doing, done}` via local `SELECT COUNT(*) ... GROUP BY status` queries. **No Firestore reads added.** The Drift mirror is kept current by the existing Firestore→Drift sync inside `TaskRepository` when the user enters event-scoped screens; the Dashboard ring reflects the latest mirror state.
13. Aggregate progress in the `MyTasksScreen` header is computed client-side from the already-watched `myAssignedTasksProvider(uid)` collection, filtered by the active `SegmentedFilterBar` value + Overdue toggle.

**Error Handling:**
14. Every screen surfaces a labeled retry action on provider errors (Dashboard, Tasks, Chat, Budget, Profile). The retry must re-trigger the relevant provider, not just call `setState`.
15. Loading states use a skeleton placeholder shape that matches the final layout (e.g., gray ring + gray bars for `EventTile`). The skeleton is reused across screens.
16. Money formatting fallback: if currency setting hasn't loaded yet, render with a neutral "$—" placeholder, never a raw locale-default that may differ from the user's choice.

**Edge Cases:**
17. Event with zero tasks: progress ring shows neutral empty state with "—" label; no division by zero. No "0/0" text.
18. Event with all tasks done: ring shows full sage fill + "{N}/{N}" label and the `done` chip activates.
19. Long event title: truncates to one line with ellipsis; full title accessible via semantics.
20. Member count badge: "1 member" / "3 members" / "12 members"; pluralization via `intl`.
21. Chat preview line: truncates to one line; urgent threads bold the preview.
22. Budget when both balances zero: `BalanceTile` collapses to a single "$0.00 all settled" message; existing `LedgerAllSettledChip` continues to render.
23. Profile when user has no payment method set: existing `_PaymentCard` "Add payment method" prompt remains; spec does not change this behaviour.
24. Text scale 200%: every screen remains usable (no overlap, no chopped text, scrollable if needed). Spec assumes the implementor adds `MediaQuery.textScalerOf` test cases.
25. Cream background contrast caveat from `app_theme.dart:24-27` still applies — body text on cream uses `onSurface` (charcoal), never `onSurfaceVariant`. New status tokens are explicitly measured on cream.
26. `EmailUnverifiedBanner` (rendered by `app_router.dart:123-126`) sits ABOVE the `ScreenHeader` on every tab. The new header does not own the top safe-area inset.

**Validation (user input):**
27. `SegmentedFilterBar` is single-select (mutually exclusive); tapping the active pill is a no-op.
28. The Overdue toggle (on `MyTasksScreen`) is independent and compatible with any segmented value.

</requirements>

<boundaries>

**Edge cases:**
- **Zero tasks on event:** ring is empty neutral, label "—", no chips highlighted.
- **All tasks done:** ring fully sage, "Done" chip visually elevated, others muted.
- **No in-progress tasks (only todo + done):** ring shows two arcs (todo track + done sage); `doing` chip count "0" remains visible but muted. This is a common state since in-progress is only set when a user explicitly taps the status chip in `TaskTile`.
- **Overdue under `Done` filter:** treat as not overdue (they're done). The Overdue toggle counts only active todo/in-progress tasks past their due date.
- **Drift mirror lag on Dashboard ring:** the per-event count provider reads from Drift; if the user has never opened a particular event's task list, the mirror may be empty even when Firestore has tasks. Acceptable for V1 (ring shows "—"); spec does not preemptively fetch tasks for every event on Dashboard load.
- **Tab swap during loading:** previous tab's content stays visible until new tab provides data (already handled by shell `_bodyKey`).
- **Provider avatar loads in `_HeroCard`:** existing `network_image_with_placeholder.dart` initials fallback handles failure; reuse — do not introduce a parallel placeholder.

**Error scenarios:**
- **Provider error on any tab:** centered icon + plain-language message ("We couldn't load your events.") + outlined retry button. No stack traces; no Snackbar-only errors.
- **Settle Up deep link fails:** existing Phase 4 fallback sheet handles it. UI here only triggers the existing flow.
- **Network offline:** local Drift cache still drives the list; no global "offline" banner introduced in this spec.
- **Sign-out failure:** existing flow handles; no design change.

**Limits:**
- **Section header title:** 40 chars before ellipsis.
- **Event tile title:** 1 line, ellipsis; full text via semantics for screen readers.
- **Chat preview:** 1 line, ellipsis.
- **Unread count pill:** displays "99+" when count exceeds 99.
- **Member count badge:** numeric; no truncation needed below 1000 members.

</boundaries>

<implementation>

**Files to create (flat under `lib/app/core/widgets/`, no subfolder):**
- `lib/app/core/widgets/status_badge.dart`
- `lib/app/core/widgets/progress_ring.dart`
- `lib/app/core/widgets/task_progress_summary.dart`
- `lib/app/core/widgets/screen_header.dart`
- `lib/app/core/widgets/section_label.dart`
- `lib/app/core/widgets/event_tile.dart`
- `lib/app/core/widgets/conversation_tile.dart`
- `lib/app/core/widgets/balance_tile.dart`
- `lib/app/core/widgets/settings_row.dart`
- `lib/app/core/widgets/stat_triplet.dart`
- `lib/app/core/widgets/segmented_filter_bar.dart`
- `lib/app/core/widgets/money_text.dart`
- `lib/app/core/widgets/skeletons.dart` — net-new shimmer placeholders.

**Files to create (application/domain layer):**
- `lib/app/features/dashboard/domain/event_type_emoji.dart` — canonical `EventType → String` emoji map.
- `lib/app/features/tasks/application/event_task_counts_provider.dart` — new Drift-backed `eventTaskCountsProvider(eventId)` returning `({int todo, int doing, int done})`. **No Firestore reads.** Reads counts from `TasksDao` (lib/app/core/database/daos/tasks_dao.dart).
- `lib/app/features/tasks/application/my_tasks_filter.dart` — minimal session-only filter state for `MyTasksScreen`: `({MyTasksSegment segment, bool overdue})` where `MyTasksSegment` is `{all, todo, doing, done}`.

**Files to modify:**
- `lib/app/core/constants/app_colors.dart` — add status + money semantic tokens with contrast comments (white / offWhite / cream / surfaceDarkElevated).
- `lib/app/core/constants/app_typography.dart` — bump body to 16; add `numberDisplay`.
- `lib/app/core/theme/app_theme.dart` — wire new typography; verify component themes still pass.
- `lib/app/core/widgets/responsive_shell.dart` — rename label "Dashboard" → "Home" AND keys `shell.bar.dashboard`→`shell.bar.home` and `shell.rail.dashboard`→`shell.rail.home` in both `NavigationBar` and `NavigationRail`. Icons unchanged.
- `lib/app/features/dashboard/presentation/dashboard_screen.dart` — adopt `ScreenHeader` (with Join trailing action), `SegmentedFilterBar`, inline Create Event button; remove the FAB.
- `lib/app/features/dashboard/presentation/widgets/event_card.dart` — rewrite contents to render `EventTile`.
- `lib/app/features/tasks/presentation/my_tasks_screen.dart` — adopt `ScreenHeader`, `TaskProgressSummary`, `SegmentedFilterBar` + Overdue toggle; existing empty state preserved.
- `lib/app/features/tasks/presentation/widgets/task_tile.dart` — retrofit currency formatting to `MoneyText`. No other changes.
- `lib/app/features/chat/presentation/chat_inbox_screen.dart` — adopt `ScreenHeader` + `ConversationTile`. `InboxTile` is replaced.
- `lib/app/features/budget/presentation/budget_ledger_screen.dart` — adopt `ScreenHeader` + `BalanceTile`. `LedgerHeroStrip` is replaced. Existing `DebtTile`, `RecentExpenseTile`, `LedgerAllSettledChip` are kept.
- `lib/app/features/budget/presentation/widgets/debt_tile.dart`, `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart` — retrofit currency formatting to `MoneyText` and apply new semantic color tokens. No structural change.
- `lib/app/features/profile/presentation/profile_screen.dart` — insert `StatTriplet` below `_HeroCard`; promote `_SettingsTile` to public `SettingsRow` and reuse. Existing `_HeroCard`, `_PaymentCard`, Sign Out button, `_DangerCard`, `_AppVersion` preserved.

**Test files that must be updated in the same change** (due to nav rename + label change):
- Any test asserting `Key('shell.bar.dashboard')`, `Key('shell.rail.dashboard')`, or finding by label text "Dashboard" in nav. Grep for these strings before touching the shell file.

**Patterns to use:**
- Each new widget is `StatelessWidget` unless it must manage focus/animation locally.
- Construct widgets from the inside out: build `StatusBadge` and `ProgressRing` first, then composites (`TaskProgressSummary`, `EventTile`).
- Pass typed callbacks (`VoidCallback`, `ValueChanged<T>`) — never `Function`.
- Use `Semantics` widgets to expose progress and money state to screen readers explicitly.
- Use `MergeSemantics` on tile rows so screen readers announce the row as a single unit.

**What to avoid and why:**
- **Do not introduce a third-party design package** (e.g., `flex_color_scheme`, `forui`). The project's theme is custom and small; adding a heavy dependency is more drag than benefit here.
- **Do not break existing widget keys** used in tests. Where a screen's tree changes meaningfully, add new keys alongside; only remove old keys after associated tests are updated in the same change.
- **Do not move providers, repositories, or models.** This is a presentation pass.
- **Do not add new Firestore queries** for progress counts. Derive from already-watched task collections.
- **Do not introduce a custom font.** Reuse the Google Fonts pipeline already wired by `google_fonts: ^6.2.1`.
- **Do not hardcode hex colors in screen files.** All color references go through `AppColors` semantic tokens.

</implementation>

<validation>

**Baseline automated coverage outcomes:**
- **Logic / state:** unit tests for any pure helpers introduced (e.g., a "compute progress counts from a list of tasks" helper if one is extracted). Cover zero tasks, all-done, mixed, all-todo.
- **UI behavior:** widget tests for every new design-system widget. At minimum: golden-or-equivalent layout test + interaction (where applicable) + semantics test.
- **Critical journeys:** robot-driven cross-screen journey covering Dashboard → Tasks → Chat → Budget → Profile navigation and verifying each screen renders its new header + first key element without overflow.

**TDD expectations (vertical slices, red → green → refactor):**
1. Slice 1: `ProgressRing` — widget test with `(done: 3, doing: 2, todo: 5)` expects label "3/10". RED → GREEN → REFACTOR.
2. Slice 2: `ProgressRing` — zero-tasks test expects "—" label and no division by zero. RED → GREEN.
3. Slice 3: `StatusBadge` — variant rendering test ensures each variant exposes the right icon + color + label. RED → GREEN.
4. Slice 4: `TaskProgressSummary` — composition test verifies it renders one `ProgressRing` and three `StatusBadge`s with the correct counts.
5. Slice 5: `EventTile` — renders type-emoji (from `EventType` map), title, date range, "{N} members" badge, and `TaskProgressSummary` ring.
6. Slice 6: `BalanceTile` — renders both balances; ratio bar collapses correctly when both zero; multi-currency disclaimer surfaces when flag is set.
7. Slice 7: `SegmentedFilterBar` — single-select pill behavior + active pill style.
8. Slice 8: `eventTaskCountsProvider` — unit test against a seeded in-memory `TasksDao` (sqlite3 in-memory, already used by migration tests) covering: zero tasks, mixed three statuses, all-done. Returns `(0, 0, 0)` when no rows; never throws.
9. Slice 9: Each screen — failing screen test asserts header text + at least one new component is present, then refactor the screen to pass.

**Testability seams required:**
- All new presentation widgets take data via constructor parameters — no Riverpod reads inside (widget tests don't need provider scopes for layout tests).
- Time-of-day greeting reads from the existing `clock` package (`clock.now()` — same CI3 seam already used by `TaskTile` at task_tile.dart:51). Tests use `withClock(Clock.fixed(...))`.
- Greeting first-name parsing extracted to a tiny pure helper (e.g., `String greetingFirstName(String? displayName)` → falls back to "there") so it's directly unit-testable.
- Currency formatting in `MoneyText` accepts a `currencyCode` parameter (matches existing `TaskTile` pattern); no global currency service required.

**Mocking policy:**
- Prefer fakes (in-memory event/task lists) over mocks for widget tests.
- Mock only the existing Settle Up deep-link launcher boundary on Budget tests, exactly as Phase 4 already does.

**Robot-driven journey tests required:**
- **Home tour journey:** open app → assert Dashboard renders greeting, at least one `EventTile`, and a `TaskProgressSummary` ring → tap Tasks tab → assert "My Tasks" header and progress strip render → tap Chat → assert "Messages" header and one `ConversationTile` → tap Budget → assert `BalanceTile` and one `DebtTile` → tap Profile → assert `_HeroCard` is still present, `StatTriplet` renders three cells, and `Sign Out` button is visible. Use the renamed `Key('shell.bar.home|tasks|chat|budget|profile')` set for navigation.
- **Progress visibility journey:** seed Drift with an event whose tasks are 2 todo + 1 doing + 3 done → open Dashboard → assert the event's tile shows "3/6" (via `Key('event.tile.{eventId}.progress.label')`) and the correct `StatusBadge` counts. Tap into Tasks tab → assert the same totals appear in `Key('tasks.header.summary')`.
- **Settle Up reuse journey:** from Budget, tap `Settle Up` on a `DebtTile` → assert the existing Phase 4 deep-link / fallback sheet is triggered. The journey ends at the boundary; it does not retest Phase 4 internals.

**Test-type mapping:**
- Robot tests: the three journeys above.
- Widget tests: every new widget (one happy path + one edge case per widget).
- Widget tests at screen level: empty state, error+retry state, and (for `MyTasksScreen`) filter-pill switching + Overdue toggle behaviour.
- Unit tests: `greetingFirstName` helper, `eventTaskCountsProvider` (via in-memory `TasksDao`), `EventType → emoji` map (exhaustive over enum values).

**Required stable selectors:**
- Preserved: `Key('shell.bar.tasks')`, `Key('shell.bar.chat')`, `Key('shell.bar.budget')`, `Key('shell.bar.profile')`, `Key('dashboard.events.list')`, `Key('dashboard.body.clamped')`, `Key('profile.body.clamped')`, `Key('profile.signOut.button')`, `Key('budget.ledger.list')`, `Key('budget.ledger.debt.{counterpartyUid}.{eventId}')`, `Key('chat.inbox.list')`, `Key('myTasks.list')`, `Key('myTasks.groupHeader.{eventId}')`, `Key('tasks.tile.{taskId}')` + descendants.
- Renamed (mandatory): `Key('shell.bar.dashboard')` → `Key('shell.bar.home')`; `Key('shell.rail.dashboard')` → `Key('shell.rail.home')`.
- Added:
  - `Key('dashboard.header.greeting')`
  - `Key('dashboard.header.joinEvent')` (trailing action)
  - `Key('dashboard.filter.upcoming')`, `Key('dashboard.filter.past')`
  - `Key('dashboard.action.createEvent')`
  - `Key('event.tile.{eventId}')`, `Key('event.tile.{eventId}.ring')`, `Key('event.tile.{eventId}.progress.label')`
  - `Key('tasks.header.summary')`
  - `Key('myTasks.filter.{all|todo|doing|done}')`, `Key('myTasks.filter.overdueToggle')`
  - `Key('budget.balance')`
  - `Key('profile.statTriplet')`

**Deterministic seams:**
- Inject a clock for the greeting.
- Inject a deterministic `Iterable` of events/tasks/conversations into widget tests; no Firestore or Drift in widget-level tests.
- Robot tests already have an established fake-firestore setup (`fake_cloud_firestore` is in dev_dependencies) — reuse.

**Accessibility validation:**
- Widget test: every primitive renders correctly at `MediaQuery.textScaler = TextScaler.linear(2.0)`. Layout must not throw overflow exceptions; gold-and-soft-fail tolerated, hard overflow not.
- Contrast: spec the AA targets in `<requirements>`; implementor verifies by hand against the new tokens. Add a comment beside each token recording the measured ratio.
- Semantics test for `ProgressRing`: announce includes done/doing/todo numbers.

**Known testing risks / gaps:**
- Goldens for cards/tiles are platform-sensitive; recommend using widget-state assertions (find by key + find by text) over pixel goldens here, except for a single representative golden of `EventTile` per platform.
- Dark-mode parity is not separately journey-tested; cover via a widget-level test that wraps each primitive in `Theme.of(context) = AppTheme.dark()` and asserts no overflow + no missing color.
- The "any age" claim is qualitative; the spec converts it to measurable bars (48dp targets, AA contrast, dynamic-type-200%). Any user research beyond that is out of scope.

</validation>

<done_when>
- All 5 main tab screens render using the new flat `lib/app/core/widgets/` primitives.
- Progress ring appears on every Dashboard `EventTile` (sourced from `eventTaskCountsProvider`) and at the top of `MyTasksScreen` (sourced client-side from `myAssignedTasksProvider`).
- Bottom nav: both the label "Home" and the key `shell.bar.home` / `shell.rail.home` are present. No tests still reference `shell.bar.dashboard` or label "Dashboard".
- Every new widget has at least one passing widget test; the three robot journeys pass end-to-end.
- `dart analyze` is clean; `flutter test` is green; `custom_lint` reports no new violations.
- No new Firestore reads are introduced for progress data — verified by grepping the diff for new `.collection(` / `FirebaseFirestore` usage in changed files. `eventTaskCountsProvider` reads only from Drift.
- Every color used in changed files routes through `AppColors` — no raw `Color(0x...)` literals in screen or widget files (excluding token definitions themselves).
- A11y spot-check at `TextScaler.linear(2.0)` on each tab screen — no overflow exceptions, no clipped controls, all tap targets ≥ 48dp.
- The five wireframes remain recognizable when held next to the implemented screens; the design language is visibly more cohesive than today.
- `EmailUnverifiedBanner` continues to render above each tab's `ScreenHeader` — confirmed visually for verified and unverified accounts.
</done_when>
