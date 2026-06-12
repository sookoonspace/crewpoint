# Plan — Task detail dark-mode pass

## Overview

Three contrast fixes on the per-event task detail screen for dark mode. Route hard-coded colours through `colorScheme`; add `CheckboxThemeData` to the dark theme.

**Spec**: `ai_specs/task-detail-dark-mode-spec.md` (read for full requirements).

## Context

- **Structure**: feature-first; theme + helpers in `lib/app/core/`.
- **State management**: pure presentation — no state changes.
- **Reference implementations**:
    - `lib/app/features/budget/presentation/widgets/donated_pill.dart` — already-shipped sage-tinted pill that reads correctly in both themes; mirror its `colorScheme`-derived structure for `_StatusBadge`.
    - `lib/app/core/widgets/reserved_checkmark_chip.dart` (Phase 7 of 2026-06-08, hardened in PR #14 fix-up) — `colorScheme.onSurface` text in both states.
    - `test/app/core/_helpers/wcag_contrast.dart` — `expectAaContrast(fg, bg, minimum: 4.5)` already in tree from the 2026-06-08 round; reuse for the `todo` pill's dark-mode contrast smoke.
- **Assumptions/Gaps**:
    - Neither theme currently defines a `CheckboxThemeData` — add to both for parity (spec req 2 already allows this).
    - `test/app/features/tasks/task_detail_screen_test.dart` exists — extend it for `_StatusBadge`.
    - No `checklist_editor_test.dart` — create new.
    - Dark scheme tokens already verified: `onSurfaceVariant = AppColors.lightGrey`, `surfaceContainerHighest = AppColors.surfaceDarkElevated`, `primary = AppColors.sageLight`, `onPrimary = AppColors.charcoalDark`.

## Plan

### Phase 1: Thin slice — `_StatusBadge` theme-aware ✓

- **Goal**: `_StatusBadge` `todo` state reads against dark surface; light mode unregressed; AA contrast verified.
- [x] TDD: light mode `todo` → `(AppColors.charcoal, AppColors.lightGrey)`. Pins existing light look.
- [x] TDD: dark mode `todo` → `(colorScheme.onSurfaceVariant, colorScheme.surfaceContainerHighest)`. RED before source edit.
- [x] TDD: dark mode `todo` pill ≥ 4.5:1 AA contrast via `expectAaContrast` from `wcag_contrast.dart`.
- [x] TDD: `inProgress` + `done` unchanged across themes (sage/sageDark bg + white text).
- [x] `lib/app/features/tasks/presentation/task_detail_screen.dart:218-237` — `_StatusBadge.build`: branch on `Theme.brightness`. Dark `todo` uses `colorScheme.onSurfaceVariant` + `colorScheme.surfaceContainerHighest`; light `todo` keeps the original `(charcoal, lightGrey)` tuple for visual continuity. Added a stable Key `tasks.detail.statusBadge` to the Container for test access.
- [x] `test/app/features/tasks/task_detail_screen_test.dart` — added `_StatusBadge — theme-aware colours` group with 5 tests (dark todo, AA contrast, light todo unchanged, inProgress + done parity across themes).
- [x] Verified: `flutter analyze` clean (sole pre-existing experimental warning); `flutter test` 803 / 803 passing (was 798; +5 new badge tests).

### Phase 2: `CheckboxThemeData` + strike-through colour ✓

- **Goal**: Checked + unchecked checkboxes visible in dark mode; completed-item strike-through legible.
- [x] TDD: dark theme — `checkboxTheme.fillColor.resolve({WidgetState.selected}) == AppColors.sageLight`. RED before source edit.
- [x] TDD: dark theme — `checkboxTheme.checkColor.resolve({WidgetState.selected}) == AppColors.charcoalDark` (AA contrast on sageLight).
- [x] TDD: dark theme — `checkboxTheme.side.color == AppColors.lightGrey` (unchecked outline visible against dark surface).
- [x] TDD: light theme — `checkboxTheme.fillColor != null` (explicit parity; doesn't drift with Material updates).
- [x] TDD (completed text, both themes): `text.style.color == colorScheme.onSurfaceVariant` + `decoration == TextDecoration.lineThrough`. Locked the pre-existing source.
- [x] TDD (unchecked text, both themes): `text.style.color == colorScheme.onSurface`, no decoration. Lock-in only.
- [x] `lib/app/core/theme/app_theme.dart:82-94 (light)` + `app_theme.dart:162-176 (dark)` — added `checkboxTheme: CheckboxThemeData(fillColor, checkColor, side)`. Dark uses sageLight + charcoalDark + lightGrey 2-px outline; light uses sage + white + charcoal 2-px outline.
- [x] `lib/app/features/tasks/presentation/widgets/checklist_editor.dart:184-194` — already routes through `colorScheme.onSurfaceVariant` for completed items (no source change needed; test locks the contract in).
- [x] `test/app/core/theme/checkbox_theme_test.dart` (new) — 4 tests on the theme contract.
- [x] `test/app/features/tasks/widgets/checklist_editor_test.dart` (new) — 4 tests covering strike-through colour + decoration across both themes for completed AND unchecked states.
- [x] Verified: `flutter analyze` clean; `flutter test` 811 / 811 passing (was 803; +8 new tests).

## Risks / Out of scope

- **Risks**:
    - Light-mode `_StatusBadge` regression — Phase 1 TDD locks the two existing colour values for `inProgress` + `done` AND the `todo` light-mode pair via the `lightGrey`/`charcoal` tuple. Watch for any callers relying on the old hard-coded values.
    - `CheckboxThemeData` cascade — adding it affects ALL checkboxes in the app, not just the checklist. Sanity-check via `flutter test` (the test suite covers other Checkbox call-sites like form-kit widgets).
    - Goldens, if any exist for the task detail screen, will need refreshing. Spec-driven assertion shape lets the implementer choose to either skip golden updates or refresh them under both themes.
- **Out of scope**:
    - New `AppColors` tokens (explicit in spec).
    - Restyling `_StatusBadge` `inProgress` / `done` past their existing sage/sageDark look.
    - Adding a high-contrast variant for users on `MediaQuery.highContrastOf(context) == true` — Material's defaults handle this once tokens are theme-aware.
    - Goldens / pixel-perfect visual diffs — out of band for this round.
