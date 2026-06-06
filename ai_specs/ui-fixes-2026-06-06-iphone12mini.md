<goal>
Fix five visual / data-binding bugs surfaced on an iPhone 12 mini in dark mode (screenshots: `docs/ui_screenshots/06_06_2026_screenshots_issues/IMG_1788.PNG`, `IMG_1789.PNG`, `IMG_1790.PNG`):

1. **Budget hero amount wraps.** "YOU OWE $333.33" splits "33.3" / "3" onto two lines, breaking right-column alignment.
2. **Settle-up tile shows raw UID.** `FknXNkuVSNNc...` appears where the counterparty's display name should be.
3. **Recent-expenses tile shows raw UID.** Payer's UID appears in the expense title fallback.
4. **Chat inbox preview shows raw UID.** Last-message sender renders as UID instead of name.
5. **White-on-light text in dark mode.**
   - Chat thread bubbles for *other* users: `AppColors.lightGrey` background paired with theme `onSurface = offWhite` (dark-mode value) → unreadable text.
   - Join Event sheet code TextField: hard-coded `fillColor: AppColors.offWhite` paired with dark-mode `headlineMedium` color → white-on-white.

These are the bugs an actual user (the reporter) hit on day-one usage. They block core trust signals (legibility, identifying who owes whom) on Budget and Chat — the two highest-traffic tabs after Dashboard.
</goal>

<background>
**Stack.** Flutter ^3.11.5, Material 3 with custom `AppTheme.light()` / `AppTheme.dark()`. ThemeMode is user-selectable and persists via `themeModeProvider` (defaults to system). Color tokens live in `lib/app/core/constants/app_colors.dart`; typography in `lib/app/core/theme/app_typography.dart`.

**State.** Riverpod providers. `globalBalanceLedgerProvider(uid)` composes `dashboardEventsProvider` + per-event `expenseListProvider(eventId)`. Chat reads come through `chat_repository` → inbox stream provider feeding `ChatInboxScreen`.

**Name-resolution pattern already in repo.** `event_chat_page.dart:102-115` watches `usersByIdProvider(usersByIds(event.memberIds))` (returns `AsyncValue<Map<String, AppUser>>`) and folds the result into a `memberNames: Map<String, String>` using the chain `displayName` → `email` → drop. The same shape is consumed by `BudgetScreen._SettleUpCard` / `_BalancesCard` for the per-event budget. The cross-event `BudgetLedgerScreen` and the chat inbox were skipped — that's the gap. **Note:** `EventModel` only exposes `memberIds: List<String>` (no `members` accessor) — the roster must be fetched via `usersByIdProvider`. The family key MUST be built with the `usersByIds(Iterable<String>)` helper (sorted, comma-joined `String`); passing a raw `List` defeats the family cache (see `users_by_id_provider.dart:11-21`).

**Helper available.** `lib/app/features/budget/data/member_name_resolver.dart` exports `resolveMemberName({uid, memberNames})` and the canonical placeholder `kRemovedMemberPlaceholder = '(no longer in event)'`. Reuse it; do not invent a parallel fallback.

**Why dark-mode bugs went unnoticed.** Most widget tests pump under `AppTheme.light()` only. The hard-coded light-surface colors (`AppColors.lightGrey`, `AppColors.offWhite`) look fine paired with light-mode `onSurface = charcoal`; they invert in dark mode where `onSurface = offWhite`.

**Files to examine:**
- `@lib/app/core/widgets/balance_tile.dart` (the wrapping amount)
- `@lib/app/core/widgets/money_text.dart` (style applied; verify no internal softWrap override)
- `@lib/app/features/budget/application/global_balance_ledger_provider.dart` (DebtRow / RecentExpenseRow definitions)
- `@lib/app/features/budget/presentation/budget_ledger_screen.dart` (wiring)
- `@lib/app/features/budget/presentation/widgets/debt_tile.dart` (renders `row.counterpartyUid` at line 59)
- `@lib/app/features/budget/presentation/widgets/recent_expense_tile.dart` (renders `payerId` fallback at line 43, 68, 80)
- `@lib/app/features/budget/data/member_name_resolver.dart` (reuse the helper + placeholder)
- `@lib/app/features/chat/presentation/chat_inbox_screen.dart` (renders `last.senderName ?? last.senderId` at line 153-156)
- `@lib/app/features/chat/application/global_inbox_provider.dart` (`InboxRow` definition at line 8-20; `globalInboxProvider` family at line 40-109 — this is where chat name enrichment lands)
- `@lib/app/features/chat/application/users_by_id_provider.dart` (the canonical roster fetch + `usersByIds` key helper — reuse, do not duplicate)
- `@lib/app/features/chat/data/chat_repository.dart` (reference only — `_rowToDomain` at line 301-308 is OUT OF SCOPE; the repo has no roster access by design)
- `@lib/app/features/chat/presentation/event_chat_page.dart` (reference: how memberNames are assembled — lines 102-115)
- `@lib/app/features/chat/presentation/widgets/message_bubble.dart` (hard-coded `AppColors.lightGrey` at line 41; conditional `AppColors.white` text at line 122-124)
- `@lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` (hard-coded `fillColor: AppColors.offWhite` at line 144; explicit border overrides override `inputDecorationTheme`)
- `@lib/app/core/theme/app_theme.dart` (light/dark schemes; dark `onSurface = offWhite`, `surfaceContainerHighest = surfaceDarkElevated`)
- `@lib/app/core/constants/app_colors.dart` (color tokens)
</background>

<user_flows>
**Primary flow — Budget tab in dark mode:**
1. User opens Budget tab.
2. Hero balance tile shows full "YOU OWE $333.33" on one line, right-aligned, never wrapped.
3. Settle-up section shows "Alice Chen" (or whatever the counterparty's display name is), not their UID.
4. Recent expenses list shows "Let's keep it affordable" or "Alice paid" (display name), never UID.

**Primary flow — Chat tab in dark mode:**
1. User opens Chat tab.
2. Each inbox row shows `<sender display name>: <message preview>` — never `<UID>: <preview>`.
3. User taps a row → chat thread opens. Other users' bubbles have legible dark text on a dark-mode-appropriate surface; own bubbles remain sageDark with white text (already legible).

**Primary flow — Join Event in dark mode:**
1. User taps "Join Event" on Dashboard.
2. Sheet opens. The 6-character code TextField has legible text as the user types (dark text on light surface in light mode; light text on dark surface in dark mode — matching the global `inputDecorationTheme`).

**Alternative flows:**
- Light mode: all of the above still look correct (no regressions).
- Member no longer in event: tiles show "(no longer in event)" via `kRemovedMemberPlaceholder`, never the UID.
- Empty display name / no displayName field: fall back to email (matches `event_chat_page.dart:108-113`), then placeholder.
- Chat message from current user in inbox: shows "You: <preview>" (existing behavior — preserve).

**Error flows:**
- `dashboardEventsProvider` errored: ledger / inbox already render their existing `error` branch. Name enrichment runs only on success — no change here.
- Event has memberIds but no roster yet loaded: tiles show placeholder + retry-on-rebuild rather than the UID.
</user_flows>

<requirements>
**Functional — Balance tile (Bug #1):**
1. The "YOU OWE" `MoneyText` must render on a single line for any amount up to at least 7 visible characters at the right column's available width on iPhone 12 mini (375 logical px) AND at iPhone SE / 320 logical px width. Use `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight)` around the right-column `MoneyText`. The right column already uses `Column(crossAxisAlignment: end)`; keep that and add the FittedBox inside it.
2. Apply `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)` to the "YOU ARE OWED" column for symmetry — the left column already uses `Column(crossAxisAlignment: start)`. Never let only one side shrink.
3. Font size for `MoneyText` continues to come from `AppTypography.numberDisplay`. Do not introduce a new font size constant; `FittedBox` handles fit.
4. The vertical divider between the two columns (`balance_tile.dart:119-123`) must remain visually centered after the fix.

**Functional — Name resolution (Bugs #2, #3, #4):**
5. Add `counterpartyName: String` (required, non-nullable) to `DebtRow` (in `global_balance_ledger_provider.dart`). Populate inside `globalBalanceLedgerProvider` as follows:
   - For each `event`, watch `usersByIdProvider(usersByIds(event.memberIds))` (the canonical roster provider; see `users_by_id_provider.dart` and `event_chat_page.dart:102-103`).
   - Treat its `AsyncValue<Map<String, AppUser>>` the same way the provider already treats `expenseListProvider` (lines 92-99): if `value == null`, return the matching `AsyncLoading`/`AsyncError`.
   - Build a per-event `memberNames` via `displayName` → `email` (matching `event_chat_page.dart:107-113`), then call `resolveMemberName(uid: settlement.toUserId, memberNames: memberNames)` from `member_name_resolver.dart` to get the final display string (placeholder if missing).
6. Add `payerName: String` (required, non-nullable) to `RecentExpenseRow` and populate the same way using `exp.payerId`.
7. Names resolve in this order: `displayName` → `email` → `kRemovedMemberPlaceholder` (`(no longer in event)`). Reuse `member_name_resolver.resolveMemberName` — do not inline a parallel fallback.
8. `DebtTile` (line 59) renders `row.counterpartyName` instead of `row.counterpartyUid`. The avatar's `_firstLetter` source also switches to `counterpartyName`. **Exception:** when `counterpartyName == kRemovedMemberPlaceholder`, render `?` in the avatar (not `(`) — match the existing empty-string behavior of `_firstLetter`. Either change the avatar branch explicitly or strip leading `(` before calling `_firstLetter`.
9. `RecentExpenseTile` (line 43) replaces `final payerLabel = exp.payerId == currentUserId ? 'You' : exp.payerId;` with `... : row.payerName`. Same `?`-avatar exception for the placeholder.
10. **Widget keys remain UID-based.** `Key('budget.ledger.settleUp.${row.counterpartyUid}.${row.event.id}')` (debt_tile.dart:86) and the matching debt-row key stay keyed by `counterpartyUid` to keep robot selectors stable (see `test/robots/budget_ledger_robot.dart`). Only the rendered text changes.
11. `ChatInboxScreen._previewLine` no longer falls back to `last.senderId`. Enrich at the provider layer:
    - In `globalInboxProvider` (`lib/app/features/chat/application/global_inbox_provider.dart`), add `final String? lastSenderName;` to `InboxRow`.
    - Before constructing each row, watch `usersByIdProvider(usersByIds(event.memberIds))` (handling `AsyncLoading`/`AsyncError` like the provider already does for `chatMessagesProvider` at lines 57-67) and resolve `latest.senderId` → name via the same `displayName` → `email` chain.
    - `_previewLine` becomes: if `senderId == currentUserId → 'You'`; else `row.lastSenderName ?? kRemovedMemberPlaceholder`. **Never** fall through to a UID.
    - The chat repository is intentionally NOT touched — keep `_rowToDomain` as-is. Layering: repos don't know about rosters.
12. The current-user case (`senderId == currentUserId → 'You'`) continues to work in `_previewLine`.

**Functional — Dark mode contrast (Bug #5):**
13. **Must fix.** In `message_bubble.dart`, replace the hard-coded `background = AppColors.lightGrey` (line 41, the "other user, not high-priority" branch) with `Theme.of(context).colorScheme.surfaceContainerHighest`. In light mode this is `AppColors.offWhite` (paired with `onSurface = charcoal` → AA-safe). In dark mode this is `AppColors.surfaceDarkElevated` (paired with `onSurface = offWhite` → AA-safe). Keep the `AppColors.sageDark` branch for `isCurrentUser` (own bubbles stay sage; existing comment at line 35-37 documents the contrast math).
14. **Verify only — fix if test fails.** The high-priority and settlement branches are NOT confirmed broken from the reporter's screenshots (IMG_1790 shows "Critical Alert" bubbles as legible because `terracottaLight.withValues(alpha:0.2)` blended over the dark scaffold paired with dark-mode `onSurface = offWhite` produces light-on-dim-dark). Add widget-test coverage for both branches under both themes (see `<validation>`). Only if the WCAG contrast assertion fails in the test, fix the failing branch with the minimal change:
    - Settlement: in dark mode, swap `AppColors.cream` for `Theme.of(context).colorScheme.surfaceContainerHighest` and keep the sage border.
    - High-priority: in dark mode, increase alpha or switch to `AppColors.terracottaDark.withValues(alpha:0.25)` only if needed.
    Light mode behavior remains unchanged in either case.
15. Text-color logic at line 122-124 (`isCurrentUser && !isHighPriority && !_isSettlement ? AppColors.white : onSurface`) keeps working once the "other user" background is theme-aware. Verify "Critical Alert" header (`AppColors.terracotta`) and "Settlement" header (`AppColors.sage`) still hit AA on the chosen dark-mode backgrounds — same contrast helper as the body-text assertion.
16. In `join_event_sheet.dart`, remove the four hard-coded `InputDecoration` overrides (`fillColor`, `border`, `enabledBorder`, `focusedBorder`) at lines 143-156 and let the global `inputDecorationTheme` (defined for light at `app_theme.dart:57-76` and dark at `app_theme.dart:127-146`) provide them. Keep `counterText: ''`, `hintText`, and `hintStyle` overrides — those are sheet-specific. **Visual verification required:** the focused-border accent will change from the sheet's previous `AppColors.sage` to the theme's `sageDark` (light) / `sageLight` (dark). This is the intended replacement; confirm it reads correctly on iPhone 12 mini in both themes during manual QA.
17. If the hint color `AppColors.lightGrey` reads poorly in light mode after the change, swap it to `Theme.of(context).colorScheme.onSurfaceVariant`.
18. The `style` on line 132 SHOULD work out-of-the-box because `AppTypography.textTheme(Brightness.dark)` already produces a brightness-aware `headlineMedium.color`. If the widget test in dark mode shows the typed text resolving to a near-white color over the dark fill (i.e. brightness-aware text style is correctly applied), no override is needed. Add `color: Theme.of(context).colorScheme.onSurface` to the `copyWith` ONLY as a safety net if the typography helper turns out to leave `headlineMedium.color == null`.

**Error Handling:**
19. If `dashboardEventsProvider` or `expenseListProvider` errors, existing error branches in `BudgetLedgerScreen` and `ChatInboxScreen` continue to fire. No new error UI required.
20. If a per-event member roster (`usersByIdProvider`) is in `AsyncLoading`, the affected provider returns `AsyncLoading` for the whole computation — matches how `expenseListProvider` is handled today (no half-states). If it's in `AsyncError`, propagate as `AsyncError`. **Do not** render the UI with placeholder names just because the roster is mid-load; let the screen show its loading skeleton.

**Edge Cases:**
21. Members removed from event after a debt was logged: `kRemovedMemberPlaceholder` shows; avatar shows `?` per req 8.
22. Display name containing only emoji / non-ASCII first char: `_firstLetter` already uses `.characters.first` — preserve.
23. Mixed-case display names: do not lowercase; render exactly as stored.
24. Very long display names in the inbox preview / debt tile: continue to use `maxLines: 1, overflow: TextOverflow.ellipsis` (already present).
25. Very long amount values (e.g. `$10,234,567.89` from a multi-currency event mistake): `FittedBox(scaleDown)` shrinks; minimum readable size is whatever `scaleDown` produces — no manual floor.

**Validation:**
26. Adding `counterpartyName` as a required field to `DebtRow` and `payerName` to `RecentExpenseRow` will break compilation in these test files — each must be updated in the same PR:
    - `test/app/features/budget/presentation/widgets/debt_tile_test.dart` (line 15)
    - `test/app/features/budget/presentation/widgets/settle_up_fallback_sheet_test.dart` (line 21)
    - `test/app/features/budget/application/settle_up_controller_test.dart` (line 97)
    - `test/app/features/budget/application/global_balance_ledger_provider_test.dart` (line 174-177; update assertions from `counterpartyUid` to additionally cover `counterpartyName`)
    - `test/app/features/dashboard/application/unread_badge_provider_test.dart` (line 50)
    - `test/app/core/widgets/overflow_320px_test.dart` (line 77)
    - `test/app/core/widgets/design_system_a11y_test.dart` (line 165)
27. `test/robots/budget_ledger_robot.dart` continues to key off `counterpartyUid` — no change required (see req 10).
28. New tests pump under both `AppTheme.light()` and `AppTheme.dark()` for the bubble + Join Event widgets (see `<validation>`).
</requirements>

<boundaries>
**In scope:**
- The five bugs enumerated in `<goal>`.
- Provider-layer enrichment of `DebtRow.counterpartyName`, `RecentExpenseRow.payerName`, and the chat inbox last-sender name.
- Theme-aware backgrounds for message bubbles + the Join Event TextField.
- Widget tests covering each fix in light and dark themes.

**Explicitly out of scope:**
- The orange "Settle Up" outlined button (terracotta-on-dark contrast) — not flagged by reporter.
- BudgetScreen (per-event variant at `lib/app/features/budget/presentation/budget_screen.dart`) — already resolves names correctly.
- Avatar background palette choice — same `AppColors.sage` / `sageLight` stays.
- Currency display, multi-currency disclaimer text, "Settle Up" CTA logic, settlement controller.
- Any new color tokens beyond what's strictly required (prefer existing tokens; introduce new ones only if the dark-mode high-priority / settlement bubble cannot be solved by existing tokens).
- iOS-specific safe area changes; the screenshots' top chrome is system, not ours.

**Failure modes & limits:**
- If `MoneyText` internally clamps `softWrap` or `maxLines` against `FittedBox`, document and fix at the `MoneyText` layer rather than working around it in `balance_tile.dart`.
- Bubble width remains constrained by the existing `maxWidth: 540` at `message_bubble.dart:52`; do not widen.
- The TextField in `join_event_sheet.dart` retains `maxLength: 6, textCapitalization: characters, textAlign: center`. The 8-px letterSpacing should remain visually distinct in both themes; if dark-mode font weight bleeds, accept it — do not redesign.
</boundaries>

<implementation>
**Files to modify:**

1. `lib/app/core/widgets/balance_tile.dart`
   - Wrap each column's `MoneyText` in `FittedBox(fit: BoxFit.scaleDown, alignment: ...)`.
   - Left column → `Alignment.centerLeft`; right column → `Alignment.centerRight`.
   - Inspect parent constraints: the `Expanded` flex (1:1) is fine; do not change layout shape.

2. `lib/app/features/budget/application/global_balance_ledger_provider.dart`
   - Add `final String counterpartyName;` to `DebtRow` (required, non-nullable).
   - Add `final String payerName;` to `RecentExpenseRow` (required, non-nullable).
   - Inside `globalBalanceLedgerProvider`, for each `event` watch `ref.watch(usersByIdProvider(usersByIds(event.memberIds)))`. Handle its `AsyncValue<Map<String, AppUser>>` with the same `value == null` switch the provider already uses for `expenseListProvider` (lines 92-99): return `AsyncLoading` / `AsyncError` accordingly.
   - Build `memberNames: Map<String, String>` by folding `displayName` → `email` (matching `event_chat_page.dart:107-113`).
   - Use `resolveMemberName(uid: ..., memberNames: memberNames)` from `member_name_resolver.dart` for each `settlement.toUserId` / `exp.payerId`.

3. `lib/app/features/budget/presentation/widgets/debt_tile.dart`
   - Replace `row.counterpartyUid` at line 59 with `row.counterpartyName`.
   - Avatar at line 46: render `?` when `row.counterpartyName == kRemovedMemberPlaceholder`, else `_firstLetter(row.counterpartyName)`. Implement as `final initial = row.counterpartyName == kRemovedMemberPlaceholder ? '?' : _firstLetter(row.counterpartyName);`.
   - Widget key on line 86 (`Key('budget.ledger.settleUp.${row.counterpartyUid}.${row.event.id}')`) and the debt-row key in `budget_ledger_screen.dart:151` stay unchanged (UID-keyed).

4. `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart`
   - Replace line 43: `final payerLabel = exp.payerId == currentUserId ? 'You' : row.payerName;`.
   - Avatar at line 68: render `?` when `payerLabel == kRemovedMemberPlaceholder`, else `_firstLetter(payerLabel)`.

5. `lib/app/features/chat/application/global_inbox_provider.dart` (Chat name resolution — Path B, single path)
   - Add `final String? lastSenderName;` to `InboxRow` (line 8-20).
   - Inside `globalInboxProvider`, for each `event` (line 56), after watching `chatMessagesProvider` watch `ref.watch(usersByIdProvider(usersByIds(event.memberIds)))`. Handle `AsyncLoading` / `AsyncError` the same way `chatMessagesProvider` is handled at lines 57-67.
   - Fold the roster into `memberNames` (same `displayName` → `email` chain) and resolve `latest.senderId` via `resolveMemberName`. Pass the result as `lastSenderName` when constructing the `InboxRow` (line 91-98).
   - **Do not modify `chat_repository.dart`.** The repository has no roster access by design; layering stays clean.

6. `lib/app/features/chat/presentation/chat_inbox_screen.dart`
   - `_previewLine` (line 150-157) becomes:
     ```dart
     if (last == null) return '';
     final senderName = last.senderId == currentUserId
         ? 'You'
         : (row.lastSenderName ?? kRemovedMemberPlaceholder);
     return '$senderName: ${_truncate(last.text, 60)}';
     ```
   - Never fall through to `last.senderId`.

7. `lib/app/features/chat/presentation/widgets/message_bubble.dart`
   - Line 41 (`else` branch): `background = Theme.of(context).colorScheme.surfaceContainerHighest;`
   - Lines 28-30 (`_isSettlement`) and 31-33 (`isHighPriority`): leave unchanged in this PR. Add widget tests under both themes (see `<validation>`); only modify if the WCAG contrast helper reports failure.
   - Line 122-124 text color: unchanged.

8. `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart`
   - Delete the `filled`, `fillColor`, `border`, `enabledBorder`, `focusedBorder` overrides (lines 143-156) — let `inputDecorationTheme` cover them.
   - Keep `counterText: ''`, `hintText: '------'`. Replace `hintStyle.color` with `Theme.of(context).colorScheme.onSurfaceVariant`.
   - Line 132 `style`: leave as-is unless the dark-mode widget test shows the typed text resolving to a light color over dark fill but failing contrast. If so, add `color: Theme.of(context).colorScheme.onSurface` to the `copyWith` as a safety net.
   - Visual QA: confirm the focused-border accent (now `sageDark` light / `sageLight` dark from the global theme) is acceptable replacement for the previous `AppColors.sage` override.

**Patterns to follow:**
- Mirror `event_chat_page.dart:105-121` for member-roster assembly.
- Reuse `resolveMemberName` from `member_name_resolver.dart` — do not duplicate the fallback chain.
- Riverpod 3 patterns; no `.notifier` calls inside `build`.
- Material 3 `ColorScheme` semantic roles (`surfaceContainerHighest`, `onSurfaceVariant`) over raw `AppColors.*` for theme-adaptive surfaces.

**What to avoid (and why):**
- Don't introduce a new top-level "member names" Riverpod provider unless one already exists — reuse what `event_chat_page` uses, or fold resolution into the existing ledger / inbox providers. New providers add stream-graph surface area.
- Don't hard-code white text in dark mode as a shortcut; that creates a "light island" inside a dark theme and breaks consistency (`onSurface` is the single source of truth).
- Don't widen the bubble or change layout to make `$333.33` fit — `FittedBox(scaleDown)` is enough.
- Don't change `AppTypography.numberDisplay` font size globally; the regression risk on every numeric display elsewhere isn't worth it.
- Don't introduce `if (kDebugMode) print(...)` or new `developer.log` calls — these bugs are not diagnostic-driven.
</implementation>

<validation>
**Test-type mapping:**
- Logic / data-binding bugs (#2, #3, #4 — name resolution): **unit tests** on the provider, **widget tests** on the tile.
- Layout bug (#1 — FittedBox): **widget test** asserting single-line render.
- Theme-adaptive bugs (#5 — bubble + Join Event dark mode): **widget tests** pumped under both `AppTheme.light()` and `AppTheme.dark()`.
- No new robot tests are required — these are tile-level fixes, not multi-screen journeys. The existing chat / budget robot tests continue to run; update fixtures if they hard-coded `counterpartyUid`.

**TDD discipline (per `Skill: flutter-tdd`):**
- Vertical slice per requirement: RED → write the failing widget/unit test → GREEN → implement the smallest change → REFACTOR.
- Behavior-first order: happy path (resolved name) → edge case (missing/placeholder) → error (provider AsyncError, unchanged).
- Testability seams already exist:
  - `DebtTile` / `RecentExpenseTile` consume plain rows → pump with a `DebtRow(counterpartyName: 'Alice', ...)` directly in tests.
  - `ChatInboxScreen` consumes `List<InboxRow>` + `currentUserId` → no Riverpod needed in widget test.
  - `BalanceTile` consumes raw doubles → pump with `youOwe: 99999.99` to force shrink.
  - `MessageBubble` + `JoinEventSheet` take a `ChatMessageModel` / no external deps → pump under `MaterialApp(theme:)` for each theme.
- Mocking: only mock the per-event roster provider (boundary). Use fakes for `dashboardEventsProvider` / `expenseListProvider` (already established pattern in the project).

**Specific tests to add (or update):**

*Test utility (shared, add once):*
A. `test/app/core/_helpers/wcag_contrast.dart` — small helper that takes two `Color`s, applies sRGB → linear conversion, computes `relativeLuminance` per WCAG 2.1, and returns `(lighter + 0.05) / (darker + 0.05)`. Add `expectAaContrast(Color fg, Color bg, {double minimum = 4.5})` matcher used by the dark-mode bubble + Join Event tests. ~15 lines. No new package — pure Dart.

*Logic / unit:*
1. `test/app/features/budget/application/global_balance_ledger_provider_test.dart` — `DebtRow.counterpartyName` resolves from roster (`displayName` → `email` → `kRemovedMemberPlaceholder`). `RecentExpenseRow.payerName` likewise. Provider returns `AsyncLoading` when `usersByIdProvider` is loading; `AsyncError` when it errors.
2. `test/app/features/chat/application/global_inbox_provider_test.dart` — `InboxRow.lastSenderName` resolves via `displayName` → `email` → placeholder. Provider returns `AsyncLoading`/`AsyncError` per roster state.

*Widget — Budget:*
3. **Extend** `test/app/core/widgets/overflow_320px_test.dart` (do not create a parallel file) — add a case that builds `BalanceTile(owedToYou: 0, youOwe: 99999.99, currencyCode: 'USD')` at 320 px width and asserts:
   - `tester.takeException()` is null.
   - The rendered "$99,999.99" `Text` painter's laid-out width ≤ its parent column's laid-out width (no overflow).
   - Reading the `Text` widget shows a single visual line (no `\n`; no `LineMetrics` count > 1 when using `RenderParagraph`).
4. `test/app/features/budget/presentation/widgets/debt_tile_test.dart` — assert resolved name renders ("Alice Chen"), UID never appears; placeholder case renders `'(no longer in event)'` AND avatar shows `?` (not `(`).
5. `test/app/features/budget/presentation/widgets/recent_expense_tile_test.dart` — payer name renders; UID never appears; placeholder + `?` avatar case covered.

*Widget — Chat:*
6. `test/app/features/chat/presentation/chat_inbox_screen_test.dart` — preview shows resolved name; "You: …" for current user; placeholder for missing; UID never appears.
7. `test/app/features/chat/presentation/widgets/message_bubble_test.dart` — for each of 4 bubble variants × 2 themes (light/dark):
   - Pump under `MaterialApp(theme: AppTheme.light())` and `AppTheme.dark()`.
   - Read background `Color` from the rendered `Container.decoration.color` and text color from the rendered `Text.style.color`.
   - Use `expectAaContrast(textColor, bgColor)` (helper A) to assert WCAG ≥ 4.5:1.
   - "Critical Alert" / "Settlement" header colors hit ≥ 4.5:1 on the bubble background under both themes.
   - These tests document the existing state; if a current branch already passes contrast, no source change needed. If a branch fails, fix per req 14.

*Widget — Join Event:*
8. `test/app/features/dashboard/presentation/widgets/join_event_sheet_test.dart` — under both themes:
   - TextField `fillColor` matches `Theme.of(context).inputDecorationTheme.fillColor` (i.e. not hard-coded).
   - Typed-text color (resolved from `TextField.style?.color` or the active textTheme's `headlineMedium.color`) satisfies `expectAaContrast(textColor, fillColor)` ≥ 4.5:1.
   - Hint contrast: `expectAaContrast(hintColor, fillColor)` ≥ 3.0 (hints are auxiliary, not body).

**Manual visual check (iOS sim, in addition to tests):**
- Launch on iPhone 12 mini simulator in dark mode.
- Budget tab: long owed amount fits on one line; debt + recent expense names visible.
- Chat tab: inbox previews show names; open a thread, send + receive a message — bubbles readable.
- Dashboard → Join Event: code input legible while typing.
- Toggle theme to light → no regression.
- Capture comparison screenshots to `docs/ui_screenshots/06_06_2026_fixes/`.

**Baseline coverage outcomes:**
- Logic: provider-layer name resolution unit tests covering displayName → email → placeholder chain.
- UI behavior: widget tests for each affected tile/widget covering happy + placeholder cases.
- Critical journeys: no new robot tests; existing chat/budget robot suites continue to pass (update fixtures only).
</validation>

<done_when>
1. On iPhone 12 mini (and any width down to 320 logical px) in dark mode, "YOU OWE $333.33" renders on a single right-aligned line.
2. Settle-up rows, Recent Expenses rows, and Chat inbox rows never display a Firebase UID; they show a resolved display name or `'(no longer in event)'`.
3. In dark mode, chat bubbles for *other* users are legible (sufficient contrast between background and `onSurface`-derived text color).
4. In dark mode, the Join Event code TextField shows light text on a dark fill (and light mode still shows dark text on a light fill).
5. New / updated widget tests cover the five fixes under both light and dark themes and pass in CI.
6. No existing tests fail. No new linter or analyzer warnings introduced.
7. Manual visual QA performed in iOS sim with comparison screenshots saved.
</done_when>
