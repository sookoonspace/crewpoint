<goal>
Promote the project's remaining ad-hoc constants (icons, asset paths, durations, numeric sizes) into dedicated `lib/app/core/constants/app_*.dart` files matching the existing `AppColors` / `AppTypography` / `AppSpacing` / `AppRadius` convention, then fix a small batch of UI bugs that hurt small-screen readability: equal-width segmented pills on Dashboard, white `Card` backgrounds for Chat + Budget tiles (currently invisible on cream), and any icon/text overflow regressions found during the sweep.

Who benefits: every future feature author (one place to swap a glyph or animation), every reviewer (easier diff audit), and every user (no blended tiles on cream, no chopped icons on a 320 px screen).

Out of scope (explicit follow-ups):
- A `custom_lint` rule to forbid raw `Icons.*` / `'assets/...'` literals (recommend manual review checklist instead).
- Internationalisation backend wiring (the existing `app_strings.dart` migration plan to ARB is unchanged).
- Skeleton pixel literals (`SkeletonBox(width: 140, height: 12)`) — these are layout-shape-matching, not design tokens, and stay.
</goal>

<background>
**Tech stack:**
- Flutter (SDK ^3.11.5), Material 3, Riverpod 3.
- Existing constants under @lib/app/core/constants/:
  - @lib/app/core/constants/app_colors.dart
  - @lib/app/core/constants/app_typography.dart
  - @lib/app/core/constants/app_spacing.dart
  - @lib/app/core/constants/app_radius.dart
  - @lib/app/core/constants/breakpoints.dart
  - @lib/app/core/constants/wcag.dart
  - @lib/app/core/constants/app_pdf_theme.dart
- Existing centralized strings: @lib/app/core/i18n/app_strings.dart (sub-objects per feature; ARB migration path documented).
- Existing core widgets relevant to UI bugs:
  - @lib/app/core/widgets/segmented_filter_bar.dart — current pills size to content (`MainAxisSize.min`) inside a horizontal `SingleChildScrollView`.
  - @lib/app/core/widgets/conversation_tile.dart — `InkWell` with no background; invisible on cream `Scaffold` bg.
  - @lib/app/features/budget/presentation/widgets/debt_tile.dart + recent_expense_tile.dart — same invisible-on-cream issue.
  - @lib/app/core/widgets/event_tile.dart — already a `Card`; the chat + budget tiles must match this pattern.
  - @lib/app/core/widgets/status_badge.dart — icon size 14 hardcoded.

**Current state (verified by grep on 2026-05-18):**
- **172 total `Icons.*` references** across `lib/` — **91 distinct glyphs**.
- Top 6 by frequency: `chevron_right` (9), `person_outline` (6), `attach_money` (6), `clear` (5), `calendar_today` (5), `account_balance_wallet_outlined` (5).
- Significant variant inconsistency between Material families of the same concept (see normalisation rule in requirement 1):
  - `dashboard` + `dashboard_outlined`
  - `calendar_today` + `calendar_today_outlined` + `calendar_month` + `calendar_month_rounded`
  - `chat` + `chat_outlined` + `chat_rounded`
  - `copy` + `copy_rounded`
  - `account_balance_wallet` + `_outlined` + `_rounded`
  - `logout` + `logout_rounded`
  - `warning_amber` + `warning_amber_rounded`
  - `task` + `task_outlined` + `task_alt_rounded`
  - `add` + `add_circle` + `add_circle_outline`
- 9 hardcoded Lottie asset paths (`error.json` × 3, `empty_state.json`, `loading.json`, `sign_out.json`, `success.json`, `profile.json` × 2).
- 2 hardcoded legal asset paths (`assets/legal/privacy-policy.md`, `assets/legal/terms-of-service.md`) in `privacy_dashboard_screen.dart`.
- Magic emoji font sizes in `EventTile` (32), `ConversationTile` (28), `StatTriplet` (22).
- Magic icon sizes: `StatusBadge` (14), `AppDateField` (18), `EmptyStatePlaceholder` (64 — single caller, see requirement 4).
- Magic settings-row divider indent (56).
- Only 36 `context.strings.*` references across all of `lib/` — many user-facing strings still hardcoded (see requirement 9).

**Constraints:**
- No new external packages.
- Behaviour-neutral migration: pre/post screenshots and pre/post tests must produce identical visible output, except for the four explicit UI fixes (equal-width pills, three tile-card wraps, overflow patches).
- All new constant files follow the existing `AppColors` shape: `abstract final class AppX { static const Foo bar = ...; }`. No singletons, no extensions, no runtime instances.
- Skeleton widget pixel literals remain inline — they're layout-shape-matching primitives that intentionally mirror the real widget dimensions; promoting them to tokens would obscure intent.
- The existing `AppRadius`, `AppSpacing`, `AppColors`, `AppTypography` files stay as-is; new files do not duplicate values.
</background>

<requirements>

**Functional — new constant files:**

1. **`lib/app/core/constants/app_icons.dart`** — `abstract final class AppIcons` with `static const IconData` fields. Each name describes the *role* (not the glyph), so swapping the underlying `Icons.X` later changes one line.

   **Normalisation rule (applies to every variant collision):**
   - **Nav unselected** → `Icons.X_outlined` (e.g., `Icons.dashboard_outlined`, `Icons.task_outlined`, `Icons.chat_outlined`, `Icons.account_balance_wallet_outlined`, `Icons.person_outline`).
   - **Nav selected** → the same glyph family's *filled* variant (e.g., `Icons.dashboard`, `Icons.task`, `Icons.chat`, `Icons.account_balance_wallet`, `Icons.person`). **No `_rounded` variant in nav.**
   - **All `_rounded` glyphs in non-nav code** → migrated to their default (non-rounded) variant. Examples: `logout_rounded` → `logout`, `warning_amber_rounded` → `warning_amber`, `copy_rounded` → `copy`, `calendar_month_rounded` → `calendar_today`, `chat_rounded` → `chat`, `login_rounded` → `login`, `task_alt_rounded` → `check_circle`. Document each collapse inline.
   - **Calendar family** → collapse all variants to `Icons.calendar_today` (most common; outlined cousin `calendar_today_outlined` also collapses here).
   - **Add family** → distinguish: `actionAdd = Icons.add`, `actionAddCircle = Icons.add_circle_outline` (always outlined to match the nav rule's spirit).

   **Naming convention (strict):**
   - Nav: `nav<Tab>` (unselected) + `nav<Tab>Filled` (selected). Examples: `navHome`, `navHomeFilled`.
   - Status: `status<Name>`. Examples: `statusTodo`, `statusDoing`, `statusDone`, `statusUrgent`, `statusInfo`.
   - Actions (verbs): `action<Verb>[Variant]`. Examples: `actionAdd`, `actionAddCircle`, `actionEdit`, `actionDelete`, `actionDeletePermanent`, `actionClose`, `actionClear`, `actionCopy`, `actionMore`, `actionOpenInNew`, `actionRetry`, `actionSearch`, `actionLogout`, `actionShare`, `actionSend`.
   - Payment methods: `payment<Method>`. Examples: `paymentVenmo`, `paymentZelle`, `paymentCashApp`, `paymentPayPal`, `paymentCash`, `paymentGeneric`.
   - Chevrons: `chevronRight`, `chevronLeft`.
   - Domain nouns: `calendar`, `member`, `members`, `notifications`, `privacy`, `currency`, `joinEvent`, `markdown`, `attachment`, `image`, `receipt`, `flag`, `priority`, `sortMenu`, `groupBy`.
   - States: `imageBroken`, `errorCompass`, `personPlaceholder`, `wifiOff`, `cloudOff`, `blocked`, `lock`.
   - Decorative one-offs (used once): keep a Material mirror name as a fallback (e.g., `wavingHand`, `volunteerActivism`, `shield`, `inboxOutlined`). Acceptable when no semantic role exists.

   **Fallback rule:** any glyph that doesn't fit the categories above gets a Material-mirror name (Material identifier converted to camelCase). The migration must NEVER leave a raw `Icons.X` in `lib/` outside `app_icons.dart`.

2. **`lib/app/core/constants/app_assets.dart`** — `abstract final class AppAssets` with `static const String` for every asset path the app loads. Required entries:
   - `lottieError = 'assets/animations/error.json'`
   - `lottieEmptyState = 'assets/animations/empty_state.json'`
   - `lottieLoading = 'assets/animations/loading.json'`
   - `lottieSignOut = 'assets/animations/sign_out.json'`
   - `lottieSuccess = 'assets/animations/success.json'`
   - `lottieProfile = 'assets/animations/profile.json'`
   - `legalPrivacyPolicy = 'assets/legal/privacy-policy.md'`
   - `legalTermsOfService = 'assets/legal/terms-of-service.md'`
   - `launcherIcon = 'assets/icons/launcher_icon.png'` (currently only in `pubspec.yaml`; ok if implementor decides this one stays in yaml only and is omitted).

3. **`lib/app/core/constants/app_durations.dart`** — `abstract final class AppDurations` with `static const Duration` for animation + timeout values used by **production** code:
   - `fast = Duration(milliseconds: 150)`
   - `medium = Duration(milliseconds: 250)`
   - `slow = Duration(milliseconds: 350)`
   - `snackbar = Duration(seconds: 4)`
   - `splash = Duration(milliseconds: 1500)` (only if a value matching this is found in the sweep).
   - **Test-only durations stay out of `lib/`.** The bounded-pump frame (50 ms) lives in a `test/harness/` helper as `kPumpFrame`, not in `AppDurations`. Test code referencing `AppDurations.X` is allowed only when the constant is also used by production code.

4. **`lib/app/core/constants/app_sizes.dart`** — `abstract final class AppSizes` with a scale for non-spacing dimensions. **Token-promotion rule: a value lands here only when used in ≥ 2 distinct call sites in `lib/`.** Single-use literals stay inline.
   - **Icon sizes**: `iconXs = 14`, `iconSm = 16`, `iconMd = 20`, `iconLg = 24`, `iconXl = 32`. (`iconHero = 64` is **not** promoted — single caller in `EmptyStatePlaceholder`; left inline with a comment "hero icon size — see AppSizes if widened to a second site.")
   - **Avatar radii**: `avatarSm = 16`, `avatarMd = 18`, `avatarLg = 20`, `avatarXl = 42` (only those with ≥ 2 sites are promoted; the implementor verifies via grep and prunes the ones with one caller).
   - **Emoji display sizes**: `emojiTile = 32` (`EventTile`), `emojiChat = 28` (`ConversationTile`), `emojiStat = 22` (`StatTriplet`). All three are single-caller today but live together as a coherent scale; document this as "emoji scale — promoted as a group even though each is single-caller, because a future tile reusing the chat-row emoji size shouldn't have to find the right magic number".
   - **Settings**: `settingsRowIndent = 56` (the existing `Divider(indent:)` value).
   - **Tile**: `progressRingSize = 48` (currently the default in `ProgressRing`).
   - Do NOT add spacing values here — those belong in `AppSpacing`.

**Functional — migration sweep:**

5. **Icon migration**: every `Icons.X` usage in `lib/` (excluding test fixtures and the new `app_icons.dart` itself) routes through `AppIcons.semanticName`. If the implementor encounters a glyph with no good semantic home, they may add it to `AppIcons` with a Material-mirror name as a fallback rather than leave it inline. Acceptance: `grep -rn "Icons\\." lib/ | grep -v "lib/app/core/constants/app_icons.dart"` returns zero matches.

6. **Asset migration**: every hardcoded `assets/...` string in `lib/` references `AppAssets.X`. Acceptance: `grep -rn "'assets/" lib/ | grep -v "lib/app/core/constants/app_assets.dart"` returns zero matches.

7. **Duration migration**: every literal `Duration(milliseconds: ...)` / `Duration(seconds: ...)` in `lib/` that *could* be one of the named tokens uses `AppDurations.X`. One-off durations with no equivalent token may remain inline. Acceptance: a grep + manual audit confirms common values (150 / 250 / 350 / 50 / 4000 / 1500 ms) all go through `AppDurations`.

8. **Numeric size migration**: every magic icon/avatar/emoji size in `lib/app/core/widgets/` and `lib/app/features/**/presentation/widgets/` routes through `AppSizes`. Magic numbers that are layout-specific (e.g., `SkeletonBox` widths and heights) stay inline.

9. **Strings audit + sub-object growth in `app_strings.dart`** (no new file, but the existing file grows): grep `lib/app/features/**/presentation/` and `lib/app/core/widgets/` for raw English string literals shown to the user. For every match that is NOT already a `context.strings.<feature>.<key>` lookup, promote it to the matching strings sub-object in `app_strings.dart`.

   **Expected new keys (sample — implementor adds others discovered during the sweep):**
   - `DashboardStrings`: `createEventCta = 'Create Event'`, `retryCta = 'Try again'`, `upcomingEventsHeader(int n) = '$n UPCOMING EVENTS'`, `pastEventsHeader(int n) = '$n PAST EVENTS'`, `errorLoading = "We couldn't load your events."`, greeting prefixes (`'Good morning'` / `'Good afternoon'` / `'Good evening'`).
   - `TasksStrings`: `myTasksTitle = 'My Tasks'`, `filterAll = 'All'`, `filterTodo = 'To Do'`, `filterDoing = 'Doing'`, `filterDone = 'Done'`, `filterOverdue = 'Overdue'`, `noMatches<Segment>(...)` for the no-matches empty-state copy, `taskTitleHint = 'Task Title'`, `descriptionOptionalHint = 'Description (optional)'`, `createTaskCta = 'Create Task'`, `saveChangesCta = 'Save changes'`, `unassignedLabel = 'Unassigned'`, `exportPdfTooltip = 'Export PDF'`.
   - `ChatStrings`: `messagesTitle = 'Messages'` (if not already present), `urgentBadge = 'URGENT'`.
   - `BudgetStrings`: `budgetTitle = 'Budget'` (if not already present), `owedToYouLabel = 'You are owed'`, `youOweLabel = 'You owe'`, `allSettledSuffix = '— all settled'`.
   - `ProfileStrings`: new sub-object if missing. Keys: `statsEvents = 'Events'`, `statsTasks = 'Tasks'`, `statsOwed = 'Owed'`, `settingsSection = 'SETTINGS'`, `paymentSection = 'PAYMENT'`, `signOut = 'Sign Out'`, `deleteAccount = 'Delete Account'`, `notifications = 'Notifications'`, `privacyDashboard = 'Privacy Dashboard'`, `addPaymentMethod = 'Add payment method'`.

   **Tag every literal "promoted" or "ok-not-user-facing"** (dev `log()`, `Semantics.label` strings asserted on by tests, identifiers like `name: 'budget.ledger'`, debug-only text). Record the list in the PR description so reviewers can verify completeness.

   **Reuse before creating:** before adding a new key, grep `app_strings.dart` for an existing equivalent. The migration MUST NOT duplicate keys with different names.

**Functional — UI bug fixes:**

10. **Equal-width segmented pills**: `SegmentedFilterBar` refactored so each pill takes `1/N` of the available horizontal width (`Expanded` per segment). The `SingleChildScrollView` wrapper is removed — the bar never scrolls horizontally. Tapping the active pill remains a no-op. Visual outcome: on Dashboard, "Upcoming" and "Past" pills are exactly 50/50; on `MyTasksScreen`, "All / Todo / Doing / Done" are exactly 25% each.

11. **White Card per tile (Chat + Budget)**: `ConversationTile`, `DebtTile`, `RecentExpenseTile` each wrapped in a `Card` (white background, default Material 3 elevation from the existing `cardTheme`, rounded per `AppRadius.borderLg`). Spacing between cards uses `AppSpacing.sm` margins. Visual outcome: tiles read as discrete, elevated rows on the cream scaffold — matching the existing `EventTile` and Profile cards.

12. **Overflow audit + fixes**: render every primary tab screen (Home, Tasks, Chat, Budget, Profile) at 320 px and 360 px viewport widths. Patch any text or icon that overflows by adding `Flexible`, `Expanded`, `maxLines + ellipsis`, or shrinking the inline icon row. Specifically suspected sites:
    - `ConversationTile`'s `_UrgentBadge` + title row (a long event title with an URGENT badge on a 320 px screen).
    - `EventTile`'s emoji + title + member count + ring row (long titles).
    - `DebtTile`'s amount + Settle Up column (long counterparty names).
    - `TaskTile`'s row of `_StatusChip` + title + budget + checklist count.

**Functional — `EventType → AppIcons` (cross-link)**:

13. The existing `event_type_emoji.dart` map is unchanged — emojis are not icons. But if any code reaches for `Icons.X` to *also* represent an event type (e.g., the Privacy Dashboard's `Icons.privacy_tip_outlined`), the icon goes through `AppIcons`.

**Error handling:**

14. Icon glyph not found at compile time → the build fails (Flutter's `IconData` is compile-checked). No runtime fallback needed.
15. Asset path mismatch (file missing from `pubspec.yaml`) → existing behaviour preserved (Lottie loader's `errorBuilder` fires; no new logging required).

**Edge cases:**

16. **Active variant icons** (nav `_outlined` vs filled): `AppIcons.navHome` is the outlined variant; selected variants get separate names (`navHomeFilled`). `ResponsiveShell` migrates both.
17. **Same glyph, different roles**: `Icons.chevron_right` is used both as a list-row affordance and as a "back" affordance in error screens. Resolution: `AppIcons.chevronRight` for the universal glyph; if a future role-specific name is needed, add it as an alias.
18. **One-off decorative icons**: a screen using `Icons.cake` exactly once may add it to `AppIcons.decorativeCake` rather than skip the migration.

**Validation (user input):**

19. No user input is added or removed by this spec.

</requirements>

<boundaries>

**Edge cases:**
- **Empty / loading branches** of Chat + Budget — the new Cards apply only to data rows; loading skeletons stay as currently rendered.
- **Dark mode** — the new Cards inherit the dark theme's `cardTheme.color`; verify no contrast regression in `surfaceDarkElevated`. Existing dark-mode parity tests cover this.
- **Tablet rail (≥ 840 px)** — equal-width pills are still equal-width; the row width is now wider, so pills get wider too. Acceptable.
- **`SegmentedFilterBar` with a single segment** — `Expanded` of one child still works; no special case needed.
- **`SegmentedFilterBar` segment-count cap** — **maximum 4 segments**. At 320 px width with 4 segments, each pill is ~75 px — already tight on the 48dp tap-target floor. Adding a 5th segment requires splitting the filter into two bars OR reverting to horizontal scroll for that specific instance. Adding a 5th segment without that decision must be caught in code review.
- **`ConversationTile` competing elements at 320 px** — when URGENT badge + 99+ unread pill + a long event title all need to fit, **the title ellipsises first**. URGENT badge and unread pill stay full-size and readable; the title (`Flexible` + `maxLines: 1` + `overflow: ellipsis`) absorbs the squeeze. URGENT does NOT shrink to icon-only — explicit readability is more valuable than seeing more title characters.
- **`AppIcons` referencing icons that change between Material versions** — accept stability of `Icons.*` identifiers (Flutter SDK contract).

**Error scenarios:**
- **Missing asset at runtime** (Lottie path correct in `AppAssets` but file deleted) — existing `Lottie.errorBuilder` fallback in `EmptyStatePlaceholder` / `LoadingAnimation` handles this; no spec change.
- **String literal accidentally re-introduced** — out of scope; manual code-review catch.

**Limits:**
- **No new dependencies** — `pubspec.yaml` unchanged.
- **No public API changes** to any widget except `SegmentedFilterBar` (whose constructor signature is preserved; the internal layout strategy changes).
- **Migration footprint**: estimated ~150 files touched for the icon/asset migration. Bundled into a single commit so reviewers can verify the sweep was exhaustive in one diff.

</boundaries>

<implementation>

**Files to create:**
- `lib/app/core/constants/app_icons.dart`
- `lib/app/core/constants/app_assets.dart`
- `lib/app/core/constants/app_durations.dart`
- `lib/app/core/constants/app_sizes.dart`

**Files to modify (constants + migration; broad sweep):**
- Every `lib/**/*.dart` file currently containing `Icons.X` (78 distinct glyphs across ~50 files). Migration is mechanical: import `app_icons.dart`, replace `Icons.X` with `AppIcons.semanticName`.
- Every `lib/**/*.dart` file currently containing a hardcoded `'assets/...'` path (~9 sites).
- Every `lib/**/*.dart` widget with a magic icon / avatar / emoji size in `lib/app/core/widgets/` or `lib/app/features/**/presentation/widgets/`.

**Files to modify (UI fixes):**
- `lib/app/core/widgets/segmented_filter_bar.dart` — replace `SingleChildScrollView` + `Row` of `Padding`-wrapped `_Pill`s with a `Row` of `Expanded`s. Keep `_Pill` API; only the parent layout changes.
- `lib/app/core/widgets/conversation_tile.dart` — wrap the `InkWell` body in a `Card` with margin `EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs)`.
- `lib/app/features/budget/presentation/widgets/debt_tile.dart` — wrap in a `Card` (same margin recipe).
- `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart` — wrap in a `Card`.
- `lib/app/features/chat/presentation/chat_inbox_screen.dart` — list now renders `Card`-wrapped rows; remove any padding between rows that doubles up with the new Card margins.
- `lib/app/features/budget/presentation/budget_ledger_screen.dart` — same wrap-tightening as Chat.
- Any tile/row where the overflow audit finds a problem — patch with `Flexible` / `maxLines: 1` / `overflow: TextOverflow.ellipsis`.

**Patterns to follow:**
- New constant files match the `AppColors` shape exactly: `abstract final class AppX { static const ... = ...; }`. No singletons, no extensions, no instance fields.
- Semantic name groups inside `AppIcons` separated by section comments (`// Navigation`, `// Status`, `// Actions`).
- One `import 'package:crewpoint_app/app/core/constants/app_icons.dart';` per migrated file; same for the other three new files.
- Card wraps reuse the existing `cardTheme` rather than building a one-off `BoxDecoration`.

**Commit-splitting strategy (mandatory):**

This is a ~150-file mechanical migration. To keep the PR reviewable, the implementation MUST land as 6 sequential commits in this order:

1. **`feat(constants): add AppIcons / AppAssets / AppDurations / AppSizes`** — four new files only; no other files touched. `flutter analyze` + `flutter test` pass (unused-import warnings on the new files are acceptable in this commit).
2. **`refactor(icons): migrate all Icons.X usages to AppIcons`** — every `Icons.X` reference in `lib/` (excluding `app_icons.dart`) switched. Apply the normalisation rule (variant collapses) atomically. Tests asserting on specific `find.byIcon(Icons.X)` updated in this same commit and called out in the message body.
3. **`refactor(assets): migrate hardcoded asset paths to AppAssets`** — Lottie + legal paths. Small commit (~10 files).
4. **`refactor(constants): migrate magic durations + sizes to AppDurations + AppSizes`** — bundled because they touch similar files and each is small in isolation.
5. **`refactor(strings): promote hardcoded user-facing literals to app_strings.dart`** — every key addition + every screen migration. Commit body lists keys added per sub-object.
6. **`fix(ui): equal-width segmented pills + white Card on chat/budget tiles + overflow patches`** — the four UI bug fixes. Smallest commit; cleanest visual diff.

Each commit is independently green (`flutter analyze` + `flutter test`). Reviewers can stop at any boundary and confirm work-in-progress is sound.

**What to avoid and why:**
- **Do not introduce an `IconRegistry` / runtime icon-by-name lookup** — Flutter `IconData` is compile-checked; a registry only adds indirection and breaks tree-shaking.
- **Do not add a barrel export** for the constants — direct file imports are explicit and let analyser warnings catch unused imports cleanly.
- **Do not change widget public APIs** beyond what's needed for the UI fixes — this spec is a constants + polish pass, not a refactor.
- **Do not migrate `Icons.X` references inside tests** — test files routinely assert on specific glyphs as a sanity check; that's fine. Acceptance criteria targets `lib/` only.
- **Do not promote dev-internal strings** (e.g., `name: 'budget.ledger'` in `developer.log` calls) — those are not user-facing.

</implementation>

<validation>

**Baseline automated coverage outcomes:**

- **Logic / state**: no logic changes; all existing logic tests stay green.
- **UI behavior**: widget tests for the four refactored widgets (`SegmentedFilterBar` equal-width, `ConversationTile` Card wrap, `DebtTile` Card wrap, `RecentExpenseTile` Card wrap).
- **Critical journeys**: existing robot journeys (`dashboard_home_journey_test.dart`, `my_tasks_progress_journey_test.dart`, `chat_inbox_open_event_journey_test.dart`, `budget_settle_up_journey_test.dart`, `profile_stats_journey_test.dart`) re-run and stay green — they exercise the touched widgets, so a regression here proves a regression in the refactor.

**TDD expectations (vertical slices, red → green → refactor):**

1. **`SegmentedFilterBar` equal-width** — widget test pumps the bar inside a 360 px-wide container with 2 segments, asserts each pill's width is ≥ 160 px (full half minus padding). RED → implement Expanded refactor → GREEN. Second test: 4 segments at 320 px → each pill width ~ 75 px. RED → already-GREEN if Expanded is correct; refactor only padding.
2. **`ConversationTile` Card wrap** — widget test asserts `find.byType(Card)` under a `ConversationTile`. RED → wrap in Card → GREEN.
3. **`DebtTile` Card wrap** — same shape.
4. **`RecentExpenseTile` Card wrap** — same shape.
5. **Icon migration** — a single golden-style test in `test/app/core/constants/app_icons_test.dart` asserts a sampling of semantic names point to expected `IconData` (e.g., `expect(AppIcons.navHome, Icons.dashboard_outlined)`). Not exhaustive — just a smoke check that the file compiles + the names resolve.
6. **Asset migration** — similar smoke test for `AppAssets` (e.g., `expect(AppAssets.lottieError, 'assets/animations/error.json')`).

**Testability seams required:**

- New constant files are top-level statics — no seams needed.
- `SegmentedFilterBar` already takes its segments + selected value via constructor; no new seams.

**Mocking policy:**

- No mocking required. Use fakes only at existing test boundaries (already in place across the project).

**Robot-driven journey tests required:**

- **Existing journeys must continue to pass.** None need rewriting because the public APIs (`Key('myTasks.filter.todo')`, `Key('chat.inbox.tile.<id>')`, etc.) are preserved.
- **No new robot journeys** are required for this spec — the four UI bugs are all single-widget regressions covered by widget tests.

**Test-type mapping:**

- Robot tests: zero new (existing suite re-run).
- Widget tests: ~6 new (per the TDD list above).
- Unit tests: zero (no logic).
- Smoke / token resolution tests: 2 new (`AppIcons` + `AppAssets`).

**Required stable selectors:**

- All existing keys preserved.
- Optional new key: `Key('segmented.pill.<value>')` on each pill child — only if equal-width tests need to assert per-pill width.

**Deterministic seams:**

- No time, network, or DB seams required. All work is presentation-layer.

**Accessibility validation:**

- The new Cards must keep tap-target ≥ 48dp (existing `InkWell` + padding inside the Card already meets this).
- `TextScaler.linear(2.0)` re-run for `ConversationTile`, `DebtTile`, `RecentExpenseTile` (extend existing `design_system_a11y_test.dart` if not already covered).
- Equal-width pills at 320 px width must still meet 48dp minimum tap target — re-test.

**Post-migration test sweep (mandatory):**

After commits 2 + 4 (icon migration + size migration) land, the full test suite must pass without modification beyond the test-file updates explicitly included in the commit. The risk surfaces here:

- Robot tests routinely use `find.byIcon(Icons.X)` as stable selectors. The icon normalisation rule (commit 2) collapses variants like `Icons.logout_rounded` → `Icons.logout`. Tests asserting on the old variant find zero widgets after the swap.
- Mitigation: grep `test/` for every `find.byIcon` immediately after commit 2's changes are staged. For each match, verify the asserted glyph survived normalisation. Tests must be updated atomically in commit 2 (not in a follow-up) and the change called out in the commit body.
- A green `flutter test` after commit 2 is the acceptance gate. A red suite means a normalisation collapse was missed somewhere; the implementation reverts the failing migration step until tests are addressed in the same commit.

**Known testing risks / gaps:**

- **Icon migration is mechanical but voluminous.** Risk: a typo on `AppIcons.X` resolves to a different glyph that "looks similar". Mitigation: the smoke test in `app_icons_test.dart` asserts a representative sample; reviewers should diff old-vs-new visually on at least the Dashboard + Tasks + Profile screens.
- **Lottie path constants** can't be smoke-tested at run time without loading the file. Acceptance is that the manual smoke test confirms the animations still play.
- **Variant normalisation is a deliberate visual change** (e.g., `logout_rounded` → `logout` changes the rendered glyph subtly). Reviewers diff the touched screens visually; if a normalised glyph reads worse than the original, the spec's normalisation rule is the right place to adjust, not the call site.

</validation>

<done_when>
- Four new files exist: `app_icons.dart`, `app_assets.dart`, `app_durations.dart`, `app_sizes.dart` under `lib/app/core/constants/`.
- `grep -rn "Icons\." lib/ | grep -v "constants/app_icons.dart"` → empty.
- `grep -rn "'assets/" lib/ | grep -v "constants/app_assets.dart"` → empty (`pubspec.yaml` reference allowed).
- Magic icon / avatar / emoji sizes in `lib/app/core/widgets/` and `lib/app/features/**/presentation/widgets/` route through `AppSizes` (one-off layout literals in `skeletons.dart` exempt).
- `SegmentedFilterBar` renders all pills at equal width (`1/N` of the row); manual check on Dashboard ("Upcoming"/"Past" identical width) and MyTasksScreen ("All"/"Todo"/"Doing"/"Done" identical width).
- `ConversationTile`, `DebtTile`, `RecentExpenseTile` each render inside a `Card`; the chat inbox and budget ledger rows visibly elevate against the cream scaffold.
- A documented `strings-audit.md` (or inline checklist in the implementation PR) lists every raw English literal found in `lib/app/features/**/presentation/`, each tagged "promoted to app_strings.dart" or "ok-not-user-facing".
- Overflow audit recorded: every primary tab screen rendered at 320 px width with no `RenderFlex overflowed` exception thrown in `flutter test`.
- `flutter analyze` is clean (only the pre-existing `TableMigration` warning is allowed).
- `flutter test` is green (existing suite + new widget tests).
- `dart run custom_lint` is clean.
</done_when>
