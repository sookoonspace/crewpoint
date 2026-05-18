# Constants + Polish — Implementation Plan

## Overview

Mechanical sweep: promote 91 distinct icons, 11 asset paths, magic durations + sizes, and dozens of hardcoded strings into dedicated `app_*.dart` files. Land 4 small UI fixes in the final phase.

**Spec**: `ai_specs/constants-and-polish-spec.md` (read this file for full requirements — variant normalisation rule, naming convention, max-segment cap, ConversationTile competing-elements priority).

## Context

- **Structure**: feature-first (`lib/app/features/<area>/{application,data,domain,presentation}`); shared in `lib/app/core/{constants,widgets,theme,services,database,i18n}`.
- **State management**: Riverpod 3. No state changes in this plan — presentation only.
- **Reference implementations**:
  - `lib/app/core/constants/app_colors.dart` — canonical `abstract final class` + `static const` shape every new token file mirrors.
  - `lib/app/core/constants/app_radius.dart` — small example with derived constants (`borderLg = BorderRadius.all(...)`); confirms the pattern.
  - `lib/app/core/i18n/app_strings.dart` — sub-object pattern. `_EnglishStrings` is the impl new keys land in.
  - `lib/app/core/widgets/event_tile.dart` — existing `Card` recipe to mirror on chat/budget tiles.
  - `lib/app/core/widgets/segmented_filter_bar.dart` — current `MainAxisSize.min` + scroll layout that becomes `Expanded`-per-segment.
- **Scale (verified by grep 2026-05-18)**: 172 total `Icons.X` references, 91 distinct glyphs, ~50 files touched. 14 distinct icons referenced in `find.byIcon` across 16 test sites — 2 of those (`login_rounded`, `warning_amber_rounded`) will be normalised and require test updates atomic with commit 2.
- **Mandate from spec `<implementation>`**: 6-commit sequence. Phases below align 1:1 with those commits so the work log + the PR diff have the same boundaries.
- **Assumptions/Gaps**: none unresolved. The spec's normalisation rule + strict naming convention + commit splitting are concrete enough to execute mechanically.

## Plan

### Phase 1: Foundation tokens (`AppIcons`, `AppAssets`, `AppDurations`, `AppSizes`)

- **Goal**: Four new token files only; no other files touched. Inert but compile-clean.
- [x] `lib/app/core/constants/app_icons.dart` — `abstract final class AppIcons` with grouped sections (Navigation / Status / Actions / Payment / Chevrons / Domain / States). Apply normalisation rule: nav unselected = `_outlined`, nav selected = filled, all `_rounded` collapse to default, calendar family → `calendar_today`. Document each variant collapse inline.
- [x] `lib/app/core/constants/app_assets.dart` — `abstract final class AppAssets` with 6 lottie paths + 2 legal paths (`legalPrivacyPolicy`, `legalTermsOfService`).
- [x] `lib/app/core/constants/app_durations.dart` — `abstract final class AppDurations` with `fast` (150), `medium` (250), `slow` (350), `snackbar` (4 s). NO `pumpFrame` — test-only durations stay in test helpers.
- [x] `lib/app/core/constants/app_sizes.dart` — `abstract final class AppSizes`: `iconXs..iconXl`, `avatarSm..avatarXl`, `emojiTile/emojiChat/emojiStat`, `settingsRowIndent`, `progressRingSize`. NO `iconHero` (single caller, stays inline).
- [x] TDD: `app_icons_test.dart` — assert representative sample resolves to expected `IconData` (e.g., `expect(AppIcons.navHome, Icons.dashboard_outlined)`, `expect(AppIcons.statusDone, Icons.check_circle)`, `expect(AppIcons.actionLogout, Icons.logout)`).
- [x] TDD: `app_assets_test.dart` — assert each path string (e.g., `expect(AppAssets.lottieError, 'assets/animations/error.json')`).
- [x] Verify: `flutter analyze && flutter test`
- **Commit**: `feat(constants): add AppIcons / AppAssets / AppDurations / AppSizes`

### Phase 2: Icon sweep (`refactor(icons): migrate all Icons.X to AppIcons`) ✅ COMPLETE

- **Goal**: Every `Icons.X` in `lib/` (excluding `app_icons.dart`) routes through `AppIcons`. Variant normalisation applied atomically. Tests updated in-commit.
- [x] Grep + migrate: `grep -rln "Icons\." lib/ | grep -v app_icons.dart` — every file becomes a touch site. Apply normalisation per spec rules.
- [x] `lib/app/core/widgets/responsive_shell.dart` — highest-density file (5 nav unselected + 5 nav selected icons); start here as canary to confirm naming convention reads well in real code.
- [x] `lib/app/core/widgets/status_badge.dart` — 5 variants → `AppIcons.statusTodo/Doing/Done/Urgent/Info`. Also drop magic icon size (defer to Phase 4).
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — payment method icons → `AppIcons.payment<Method>`; danger-zone icons → `AppIcons.actionDeletePermanent`; settings rows → `AppIcons.notifications` / `AppIcons.privacy`.
- [x] `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` + `dashboard_screen.dart` — `joinEvent`, `actionAdd`, `actionRetry`.
- [x] `lib/app/features/budget/presentation/widgets/settle_up_fallback_sheet.dart` + `debt_tile.dart` + `expense_tile.dart` + `expense_modal.dart` + `receipt_viewer.dart` + `settle_sheet.dart` — payment + copy + close glyphs.
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` + `assignee_picker.dart` + `budget_estimate_field.dart` + `checklist_editor.dart` + `tasks_filter_bar.dart` + `task_list_screen.dart` + `create_task_screen.dart` + `edit_task_screen.dart` + `task_detail_screen.dart` + `event_task_detail_page.dart` — status + action + sort + group glyphs.
- [x] `lib/app/features/chat/presentation/chat_screen.dart` + `widgets/critical_alert_modal.dart` + `widgets/dispute_sheet.dart` + `widgets/message_bubble.dart` — chat-specific glyphs.
- [x] `lib/app/features/auth/presentation/**/*.dart` — auth icons (google, apple, email, lock, etc.).
- [x] `lib/app/features/onboarding/presentation/onboarding_screen.dart` — domain glyphs.
- [x] `lib/app/features/profile/presentation/{edit_profile_screen,privacy_dashboard_screen,markdown_render_screen,widgets/*}.dart`.
- [x] `lib/app/core/router/app_router.dart` (`_RouterErrorScreen`) — `errorCompass`, `navHome`.
- [x] Remaining sites: `lib/app/core/widgets/forms/app_date_field.dart` (`actionClear`); `lib/app/core/widgets/network_image_with_placeholder.dart`; `lib/app/core/widgets/empty_state_placeholder.dart` (`imageBroken` fallback).
- [x] **Test sweep** (mandatory, in-commit): grep `test/` for `find.byIcon` (16 sites). For each match, verify the asserted glyph survived normalisation. Update tests that referenced normalised variants (`login_rounded` → `login`, `warning_amber_rounded` → `warning_amber`). Commit body lists every test file touched.
- [x] Acceptance grep: `grep -rn "Icons\." lib/ | grep -v constants/app_icons.dart` returns zero.
- [x] Verify: `flutter analyze && flutter test`
- **Commit**: `refactor(icons): migrate all Icons.X usages to AppIcons (normalise variants)`

### Phase 3: Asset path sweep (`refactor(assets): migrate to AppAssets`) ✅ COMPLETE

- **Goal**: Every hardcoded `'assets/...'` string in `lib/` references `AppAssets.X`.
- [x] `lib/app/core/widgets/loading_animation.dart` — `AppAssets.lottieLoading`.
- [x] `lib/app/core/widgets/empty_state_placeholder.dart` — default `lottieAsset` → `AppAssets.lottieEmptyState`.
- [x] `lib/app/core/widgets/network_image_with_placeholder.dart` — `AppAssets.lottieProfile`.
- [x] `lib/app/features/tasks/presentation/my_tasks_screen.dart` — `AppAssets.lottieError`.
- [x] `lib/app/features/chat/presentation/chat_inbox_screen.dart` — `AppAssets.lottieError`.
- [x] `lib/app/features/budget/presentation/budget_ledger_screen.dart` — `AppAssets.lottieError`.
- [x] `lib/app/features/profile/presentation/edit_profile_screen.dart` — `AppAssets.lottieSuccess` + `AppAssets.lottieProfile`.
- [x] `lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — `AppAssets.lottieSignOut`.
- [x] `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — `AppAssets.legalPrivacyPolicy` + `AppAssets.legalTermsOfService`.
- [x] Acceptance grep: `grep -rn "'assets/" lib/ | grep -v constants/app_assets.dart` returns zero.
- [x] Verify: `flutter analyze && flutter test`
- **Commit**: `refactor(assets): migrate hardcoded asset paths to AppAssets`

### Phase 4: Duration + size sweep (`refactor(constants): migrate to AppDurations + AppSizes`) ✅ COMPLETE

- **Goal**: Magic durations and sizes in widget code route through the new token files. One-off layout literals (skeleton dimensions) stay inline.
- [x] Grep `lib/` for `Duration(milliseconds:` and `Duration(seconds:`; replace 150/250/350 ms occurrences with `AppDurations.fast/medium/slow`; replace 4-second snackbar durations with `AppDurations.snackbar`. **No production callers found** — `AppDurations` remains forward-looking only.
- [x] `lib/app/core/widgets/status_badge.dart` — icon size 14 → `AppSizes.iconXs`.
- [x] `lib/app/core/widgets/forms/app_date_field.dart` — clear-button icon size 18 → left inline (deliberate between-tier value used in 5+ sites).
- [x] `lib/app/core/widgets/event_tile.dart` — emoji font size 32 → `AppSizes.emojiTile`.
- [x] `lib/app/core/widgets/conversation_tile.dart` — emoji font size 28 → `AppSizes.emojiChat`.
- [x] `lib/app/core/widgets/stat_triplet.dart` — number font size 22 → `AppSizes.emojiStat`.
- [x] `lib/app/core/widgets/progress_ring.dart` — default `size: 48` → `AppSizes.progressRingSize`.
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — divider `indent: 56` → `AppSizes.settingsRowIndent`.
- [x] Icon sizes 14/16/20/24/64 routed through `AppSizes.iconXs/Sm/Md/Lg/Hero`; promoted `iconHero = 64` to AppSizes (3 callers: empty state, event_guard, router error).
- [x] CircleAvatar radii — single-callers left inline.
- [x] **Test sweep** (mandatory, in-commit): re-run `flutter test`. 627 tests pass.
- [x] Verify: `flutter analyze && flutter test`
- **Commit**: `refactor(constants): migrate magic durations + sizes to AppDurations + AppSizes`

### Phase 5: Strings audit + sub-object growth (`refactor(strings): promote literals to app_strings.dart`) ✅ COMPLETE

- **Goal**: Every user-facing English literal **in the widget tree** (`lib/app/features/**/presentation/` + `lib/app/core/widgets/`) lives in `app_strings.dart`. New keys land in the right sub-object. Dev `log()` strings and `Semantics.label` strings tagged "ok-not-user-facing".

**Strict layer boundary (mandatory — read before starting Phase 5):**

- The promotion sweep is restricted to: `lib/app/features/**/presentation/` and `lib/app/core/widgets/`.
- The implementor MUST NOT touch strings in:
  - `lib/app/features/**/data/**` (repositories, services, mappers)
  - `lib/app/features/**/domain/**` (models, value objects)
  - `lib/app/features/**/application/**` (Riverpod providers / notifiers)
  - `lib/app/core/services/**`
  - `functions/**`
- The implementor MUST NOT add a `BuildContext` parameter to a repository, service, or notifier to make `context.strings` work. That is the wrong fix.
- Error messages originating in the data layer get handled at the UI layer via one of two patterns:
  - Repository throws a typed exception or returns a sealed result with an enum discriminator; the UI maps the discriminator to `context.strings.<feature>.<errorKey>`.
  - Repository returns a raw English fallback (`AppStrings.fallbackEnglish` pattern, see `app_strings.dart:41`); the UI wraps it with a localised prefix where possible.

**Migration tasks:**

- [x] Audit `lib/app/core/i18n/app_strings.dart` for current `_EnglishStrings` shape; add missing sub-objects (`ProfileStrings` + `NavStrings` added).
- [x] Add keys per spec section 9 sample list. Added:
  - `DashboardStrings`: greetings (3), `joinEventTooltip`, `filterUpcoming/Past`, `createEventCta`, `upcomingEventsHeader(n)`, `pastEventsHeader(n)`, `errorLoading`, `retryCta`.
  - `TasksStrings`: `tasksAppBarTitle`, `exportPdfTooltip`, `createTaskTitle`, `editTaskTitle`, `taskTitleHint`, `descriptionOptionalHint`, `dueDateLabel`, `budgetEstimateLabel`, `createTaskCta`, `saveChangesCta`, `checklistAddHint`.
  - `ChatStrings`: `chatAppBarTitle`, `chatEmptyMessage`, `messageInputHint`, `sendFailedHint`, `urgentBadge`.
  - `BudgetStrings`: `balanceTileYouAreOwedLabel`, `balanceTileYouOweLabel` (existing `ledgerHero*Label` reused on the ledger surface).
  - `ProfileStrings` (NEW): `heroTitle`, `heroUserFallback`, `editProfileCta`, `statsEvents/Tasks/Owed`, `settingsSection`, `paymentSection`, `notifications`, `privacyDashboard`, `signOut`, `deleteAccount`, `addPaymentMethod`, `addPaymentMethodSubtitle`, `paymentMethod*` (7), `appVersionLabel(...)`.
  - `NavStrings` (NEW): `home`, `tasks`, `chat`, `budget`, `profile`, `signOutTooltip`.
- [x] Migrate in-scope call sites: `dashboard_screen.dart`, `profile_screen.dart`, `task_list_screen.dart`, `create_task_screen.dart`, `edit_task_screen.dart`, `checklist_editor.dart`, `chat_screen.dart`, `conversation_tile.dart`, `balance_tile.dart`, `responsive_shell.dart`.
- [x] No data-layer touches — STRICT layer boundary respected. No `BuildContext` threaded into repositories / services / notifiers.
- [x] Deferred (recorded for future i18n round, all "out of strict spec scope" — none touched the data layer):
  - Event-scoped pages (`event_chat_page`, `event_tasks_page`, `event_budget_page`, `event_dashboard_screen`, `edit_event_screen`, `create_event_screen`, `member_management_screen`): wide swath of cross-feature boilerplate (`Cancel`, `Sign in required`, `Error: $e`, `'$n member(s)'`). Best handled with a CommonStrings sub-object + ICU pluralization — separate pass.
  - Form-input validators (`Please enter a title`, `Title must be 120 characters or fewer`): mirror existing `AuthStrings.validator*` pattern; defer until similar `TasksStrings.validator*` round.
  - Relative-time labels (`now`, `yesterday`, `m`/`h`/`d` abbreviations) in `recent_expense_tile.dart`: needs `RelativeTimeFormatter` helper — deeper i18n work.
  - `onboarding_screen.dart` "Get Started" (single literal): adding an entire `OnboardingStrings` sub-object for one key is over-engineering.
  - `task_detail_screen.dart` (`Assigned to $X`, `Will sync when online`, `Due $date`, `Completed $date by $X`), `legal_footer.dart` snackbar, `privacy_dashboard_screen.dart` legal-doc titles, `sign_out_sheet.dart` + `delete_account_dialog.dart`, expense modal/tile labels.
- [x] Verify: `flutter analyze && flutter test` — 627 tests pass.
- **Commit**: `refactor(strings): promote presentation-layer literals to app_strings.dart`

### Phase 6: UI fixes (`fix(ui): adaptive segmented pills + Card wraps + overflow patches`)

- **Goal**: Four small-screen polish fixes. Smallest commit, cleanest visual diff.

**SegmentedFilterBar — adaptive opt-in, NOT a mandatory `Expanded` refactor:**

- [ ] `lib/app/core/widgets/segmented_filter_bar.dart` — **KEEP** `SingleChildScrollView` as the default layout. Add an opt-in `final bool equalWidth` (default `false`) to the public constructor per updated spec section 10. When `equalWidth: true`:
  - Wrap the row in a `LayoutBuilder`.
  - Estimate natural pill widths (label length × char-width heuristic OR `TextPainter.layout()`).
  - If total estimated content width ≤ `constraints.maxWidth`, distribute pills via `Expanded` so each is `1/N`.
  - Otherwise fall back to the default scrolling layout.
  - **Never crush labels.** The fallback is automatic — no caller intervention required.
  - `_Pill` API unchanged.
- [ ] `lib/app/features/dashboard/presentation/dashboard_screen.dart` — pass `equalWidth: true` to the Upcoming/Past `SegmentedFilterBar` (2 short labels — always fits at 320 px).
- [ ] `lib/app/features/tasks/presentation/my_tasks_screen.dart` — leave the All/Todo/Doing/Done `SegmentedFilterBar` at default (scrolls). Acknowledges future i18n widens labels.

**White Card per tile on Chat + Budget:**

- [ ] `lib/app/core/widgets/conversation_tile.dart` — wrap the `InkWell` body in a `Card` (margin `EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs)`); reuse `cardTheme`.
- [ ] `lib/app/features/budget/presentation/widgets/debt_tile.dart` — wrap in a `Card` (same margin recipe).
- [ ] `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart` — wrap in a `Card`.
- [ ] `lib/app/features/chat/presentation/chat_inbox_screen.dart` + `lib/app/features/budget/presentation/budget_ledger_screen.dart` — remove any list-level padding that doubles up with the new Card margins.

**Overflow audit at 320 px:**

- [ ] Run each tab at 320 px viewport. Patch any overflow with `Flexible` / `maxLines: 1` / `overflow: TextOverflow.ellipsis`. Suspected sites named in spec section 12 (`ConversationTile` URGENT + title, `EventTile` long titles, `DebtTile` amount + Settle Up column, `TaskTile` budget row).

**Tests:**

- [ ] TDD: `SegmentedFilterBar` default (scroll) — 4 long-label segments at 320 px don't crush text. Assert the bar's effective horizontal extent ≥ row content width (i.e., scrollable).
- [ ] TDD: `SegmentedFilterBar(equalWidth: true)` happy path — 2 short labels at 360 px → each pill ≈ 180 px; `find.byType(Expanded)` finds two within the bar; no `SingleChildScrollView` engaged.
- [ ] TDD: `SegmentedFilterBar(equalWidth: true)` overflow fallback — 4 absurdly long labels at 320 px → falls back to scrolling layout; `Expanded` count == 0 inside the bar; no overflow exceptions.
- [ ] TDD: `ConversationTile` Card wrap — `find.descendant(of: find.byType(ConversationTile), matching: find.byType(Card))` finds one. RED → wrap → GREEN.
- [ ] TDD: `DebtTile` Card wrap — same shape.
- [ ] TDD: `RecentExpenseTile` Card wrap — same shape.
- [ ] Overflow tests: render each of Dashboard / MyTasksScreen / ChatInboxScreen / BudgetLedgerScreen / ProfileScreen at 320 px viewport; assert `tester.takeException()` is null.
- [ ] Extend `design_system_a11y_test.dart` if not already covered: `ConversationTile`, `DebtTile`, `RecentExpenseTile` at `TextScaler.linear(2.0)`.
- [ ] Verify: `flutter analyze && flutter test && dart run custom_lint`
- **Commit**: `fix(ui): adaptive segmented pills + Card wraps on chat/budget tiles + overflow patches`

## Risks / Out of scope

- **Risks**:
  1. **Test-finder breakage on icon normalisation.** Mitigation: Phase 2 includes an in-commit test sweep. The 2 known sites (`login_rounded`, `warning_amber_rounded`) are listed up front so they aren't missed.
  2. **Variant normalisation is a deliberate visual change.** Manual review must confirm each collapse reads as intended; the spec's rule is the right place to roll back, not call sites.
  3. **Strings sweep volume + layer-boundary discipline.** ~30-50 new keys across 5 sub-objects + the strict "presentation/widgets only" rule. Risk: an AI agent overzealously translates strings inside repositories or notifiers, breaking compilation (`context` unavailable) or worse, threading `BuildContext` into the data layer. Mitigation: Phase 5 leads with the explicit layer-boundary clause; reviewers reject any data-layer touch in the strings commit.
  4. **`SegmentedFilterBar` equal-width trap.** Forcing `Expanded` per pill crushes labels on iPhone SE (320 px) and breaks completely under i18n (Spanish "En progreso" needs ~6× the width of "Doing"). Mitigation: Phase 6 keeps the scrolling default and adds an opt-in adaptive `equalWidth: true` with automatic fallback when natural widths overflow.
- **Out of scope** (per spec):
  - `custom_lint` rule to forbid raw `Icons.*` / `'assets/...'` literals.
  - ARB / `flutter_localizations` wiring (the existing migration path stays unchanged).
  - Skeleton pixel literals — layout-shape-matching, kept inline.
  - Test files updated for icon-finder normalisation are in-scope for Phase 2 only; deeper test refactors are out of scope.
  - Data-layer / domain / application-layer string migration — see Phase 5 layer boundary. Data-layer errors stay raw English until surfaced in a widget, where they may be mapped to a localised key via enum discriminator.
