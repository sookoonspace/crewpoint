# Plan — iPhone 12 mini UI fixes (2026-06-06)

## Overview

Fix 5 dark-mode/data bugs: balance hero wrap, UID-leak in Budget tiles + Chat inbox, white-on-light contrast in chat bubbles + Join Event TextField. Enrich names at provider layer; theme-aware surfaces.

**Spec**: `ai_specs/ui-fixes-2026-06-06-iphone12mini.md` (read for full requirements).

## Context

- **Structure**: feature-first (`lib/app/features/{budget,chat,dashboard}/{application,data,domain,presentation}`).
- **State management**: Riverpod 3, `Provider.family<AsyncValue<...>, String>` pattern. AsyncLoading/AsyncError unwrap via `value == null` switch (see `global_balance_ledger_provider.dart:92-99`).
- **Reference implementations**:
  - `lib/app/features/chat/presentation/event_chat_page.dart:102-115` — canonical `usersByIdProvider(usersByIds(event.memberIds))` → `memberNames` fold (displayName → email).
  - `lib/app/features/chat/application/users_by_id_provider.dart` — family key MUST use `usersByIds(Iterable<String>)` helper (sorted, comma-joined `String`); raw `List` defeats cache.
  - `lib/app/features/budget/data/member_name_resolver.dart` — `resolveMemberName` + `kRemovedMemberPlaceholder`. Reuse, don't duplicate.
  - `test/app/features/chat/widgets/message_bubble_test.dart` — pattern for pumping `MessageBubble` in sized parent.
- **Assumptions/Gaps**: None blocking. Spec explicitly defers `chat_repository._rowToDomain` (out of scope by design — repo has no roster access).

## Plan

### Phase 1: Provider-layer name enrichment (vertical slice) ✓

- **Goal**: `DebtRow.counterpartyName`, `RecentExpenseRow.payerName`, `InboxRow.lastSenderName` resolved end-to-end so UIDs never leak to UI.
- [x] `lib/app/features/budget/application/global_balance_ledger_provider.dart` — add `counterpartyName` (req) to `DebtRow`; add `payerName` (req) to `RecentExpenseRow`. Per-event watch `usersByIdProvider(usersByIds(event.memberIds))`; handle null via existing AsyncLoading/Error switch. Fold roster → `memberNames` (displayName → email). Use `resolveMemberName` for both rows.
- [x] `lib/app/features/chat/application/global_inbox_provider.dart` — add `final String? lastSenderName;` to `InboxRow`. Watch same roster provider per active event; fold and resolve `latest.senderId` via same chain.
- [x] `lib/app/features/chat/presentation/chat_inbox_screen.dart:150-157` — rewrite `_previewLine`: current user → `'You'`; else `row.lastSenderName ?? kRemovedMemberPlaceholder`. Never `last.senderId`.
- [x] `lib/app/features/budget/presentation/widgets/debt_tile.dart:46,59` — render `row.counterpartyName`; avatar `?` when name == placeholder, else `_firstLetter(counterpartyName)`. Keep `Key('budget.ledger.settleUp.${row.counterpartyUid}.${row.event.id}')` (line 86) UID-keyed.
- [x] `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart:43,68` — `payerLabel` from `row.payerName`; same `?` exception for placeholder.
- [x] `lib/app/features/budget/presentation/budget_ledger_screen.dart:151` — confirm `budget.ledger.debt.{uid}.{eventId}` key stays UID-based (no source change expected).
- [x] Update compile-breaking test fixtures (add `counterpartyName`/`payerName`):
  - `test/app/features/budget/presentation/widgets/debt_tile_test.dart:15`
  - `test/app/features/budget/presentation/widgets/settle_up_fallback_sheet_test.dart:21`
  - `test/app/features/budget/application/settle_up_controller_test.dart:97`
  - `test/app/features/budget/application/global_balance_ledger_provider_test.dart:174-177`
  - `test/app/features/dashboard/application/unread_badge_provider_test.dart:50`
  - `test/app/core/widgets/overflow_320px_test.dart:77`
  - `test/app/core/widgets/design_system_a11y_test.dart:165`
- [x] TDD: `global_balance_ledger_provider` resolves `counterpartyName` from roster — happy (displayName), then email-fallback, then placeholder when missing. Repeat for `payerName`. Then AsyncLoading propagation when roster is loading; AsyncError propagation when roster errors.
- [x] TDD: `global_inbox_provider` resolves `lastSenderName` — same three-step chain + Async state propagation.
- [x] TDD: `debt_tile` renders resolved name; never the UID; placeholder case → text == `'(no longer in event)'` AND avatar text == `'?'`.
- [x] TDD: `recent_expense_tile` same shape (name renders; placeholder + `?` avatar).
- [x] TDD: `chat_inbox_screen._previewLine` shows `'You: …'` for self; `'<name>: …'` for others; `'(no longer in event): …'` when missing; UID never appears.
- [x] Verify: `flutter analyze && flutter test`.

### Phase 2: Balance tile single-line + dark-mode contrast ✓

- **Goal**: Hero amount renders one line at 320 px; chat bubbles + Join Event TextField legible in dark mode; WCAG AA verified.
- [x] `test/app/core/_helpers/wcag_contrast.dart` (new, ~50 lines) — `relativeLuminance(Color)` (sRGB→linear per WCAG 2.1) + `contrastRatio(Color, Color)` + `expectAaContrast(Color fg, Color bg, {double minimum = 4.5})` matcher.
- [x] `lib/app/core/widgets/balance_tile.dart:107-115,131-139` — wrap left `MoneyText` in `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)`; right `MoneyText` in `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight)`. No font-size change.
- [x] `lib/app/features/chat/presentation/widgets/message_bubble.dart:41` — replace `background = AppColors.lightGrey` with `Theme.of(context).colorScheme.surfaceContainerHighest`. Settlement + high-priority branches needed dark-mode swap too (contrast test failed → fix applied): both fall through to `surfaceContainerHighest` in dark mode while keeping cream/terracotta tint in light mode; border carries the semantic signal.
- [x] `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart:143-156` — delete `filled`, `fillColor`, `border`, `enabledBorder`, `focusedBorder` overrides (let `inputDecorationTheme` cover). Keep `counterText: ''`, `hintText: '------'`. Swap `hintStyle.color` to `Theme.of(context).colorScheme.onSurfaceVariant`. `style` retains `letterSpacing: 8` + `fontWeight: w700` via `headlineMedium.copyWith` so the typed-text color inherits the brightness-aware textTheme color (no explicit override needed).
- [x] **Extend** `test/app/core/widgets/overflow_320px_test.dart:77` — add case: `BalanceTile(owedToYou: 0, youOwe: 99999.99, currencyCode: 'USD')` at 320 px → `tester.takeException() == null`; rendered widget height < 50px (single line via FittedBox); inner Text contains "99,999.99".
- [x] TDD (long amount): assert single-line render for `$99,999.99` at 320 px (test above).
- [x] TDD (message_bubble × 2 themes): for each of 4 variants (own normal, other normal, high-priority, settlement), pump under `Theme(data: AppTheme.light()/dark())` and assert `expectAaContrast(text, bg, ≥4.5)`. Settlement + high-priority dark-mode failures triggered the source fix above.
- [x] TDD (`test/app/features/dashboard/presentation/widgets/join_event_sheet_test.dart`, new): under both themes — `TextField` `fillColor` is `null` (theme provides it); typed-text color ≥ 4.5:1 on the active fill; hint color ≥ 3.0:1 on fill.
- [x] Verify: `flutter analyze && flutter test`. 743 tests passing; only pre-existing experimental_member_use warning.

### Phase 3: Manual visual QA + screenshot capture ✓

- **Goal**: Confirm fixes on iPhone 12 mini sim in both themes; capture comparison artifacts.
- [x] Run app on iPhone 12 mini sim, dark mode. Verify: Budget hero one-line; Settle-up + Recent expenses show display names; Chat inbox previews show names; Chat thread other-user bubbles legible; Join Event code input legible while typing; focused-border accent (`sageLight` in dark from theme) acceptable.
- [x] Toggle light mode; re-verify same screens; confirm no regression.
- [x] Save before/after screenshots — skipped (user confirmed fixes visually).
- [x] Verify: `flutter analyze && flutter test` (final green run — 743 passing).

### Out-of-band: iOS flavor regression repair

While verifying on-device, two iOS-flavor regressions surfaced that pre-dated this plan but blocked acceptance:

- [x] App name showed as "Runner" because pbxproj's per-flavor `buildSettings` hard-coded `PRODUCT_NAME = "$(TARGET_NAME)"`, overriding the xcconfig — removed from the 9 per-flavor Runner configs.
- [x] DEV / STG icon badge missing because the AppIcon catalog had been collapsed to a single set — restored via per-flavor `AppIcon-{dev,stg,main}.appiconset` catalogs, matching xcconfigs, plus `scripts/generate_ios_per_flavor_icons.sh` wrapper.

## Risks / Out of scope

- **Risks**:
  - `usersByIdProvider` is `FutureProvider.family` — adding a per-event watch inside `globalBalanceLedgerProvider` (already iterates events) and `globalInboxProvider` will fan out N futures. Acceptable: events are O(<20), and `usersByIds` key dedupes overlapping rosters in cache.
  - Settlement bubble in dark mode is the suspected hidden failure surfaced by Phase-2 contrast tests; minimal fix (`surfaceContainerHighest`) is pre-planned but not yet committed in source.
- **Out of scope**:
  - `chat_repository._rowToDomain` (no roster access by design).
  - Per-event `BudgetScreen` (already resolves names correctly).
  - Settle-Up CTA terracotta-on-dark contrast (not reported).
  - New `AppColors` tokens.
  - Currency formatting, multi-currency disclaimer, settlement controller.
