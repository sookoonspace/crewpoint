<goal>
Fix three dark-mode contrast / readability issues on the per-event task detail screen flagged by the 2026-06-11 QA pass (`docs/ui_screenshots/issues_06_11_2026/IMG_1874.PNG`). The screen renders against the dark navy app background but three elements still use light-mode-only colour tokens: the status pill, the checklist checkboxes, and the strikethrough text on completed items.

Beneficiaries: testers (cleaner task detail view), users in dark mode (currently struggle to read the status pill and check states), engineering (one more screen brought into compliance with the theme switcher landed earlier).
</goal>

<background>
- Stack: Flutter / Dart 3 / Material 3 dark theme — see `lib/app/core/theme/app_theme.dart:88-110` for the dark `ColorScheme` definition. `onPrimary` = `AppColors.charcoalDark`, `onSurface` = `AppColors.offWhite`.
- Surface in scope: `lib/app/features/tasks/presentation/task_detail_screen.dart`. The page wrapper is `lib/app/features/tasks/presentation/event_task_detail_page.dart` (auth / repo plumbing only — no chrome).
- Files to examine:
    - @lib/app/features/tasks/presentation/task_detail_screen.dart — the screen body + `_StatusBadge`.
    - @lib/app/features/tasks/presentation/widgets/checklist_editor.dart — `Checkbox` + line-through text.
    - @lib/app/core/theme/app_theme.dart — current dark `ColorScheme`. Will add a `CheckboxThemeData` here so the fix is themed, not per-widget.
    - @lib/app/core/constants/app_colors.dart — token table; pick existing tokens, do not add new ones.
    - Existing reference: `lib/app/features/budget/presentation/widgets/donated_pill.dart` — already-shipped dark-aware pill we can mirror for `_StatusBadge`.
- Confirmed bugs from the screenshot:
    1. **Status pill "To Do"** renders dark text (`AppColors.charcoal`) on a pale-grey pill (`AppColors.lightGrey`) — see `task_detail_screen.dart:220-224`. The other two states (`inProgress`, `done`) use sage-on-white which still reads in dark mode, but `todo` is a stark inversion against the dark surrounding chrome.
    2. **Checklist checkboxes** use raw `Checkbox` (`checklist_editor.dart:165-171`) with no `CheckboxThemeData` in the dark scheme. Material's default fills + outlines bias toward light themes — checked boxes paint a charcoal fill with low-contrast ✓; unchecked boxes are outline-only against the navy surface and easy to miss.
    3. **Strikethrough text on completed items** at `checklist_editor.dart:184-196` uses the default text color; in dark mode that's `offWhite` but the strike-through visual still renders dim because the line-through colour matches the text. Acceptable, but tied to (2): once checkboxes contrast, the strike pattern should follow.
- Assumptions / gaps:
    - Light mode is not regressing — the existing `(charcoal, lightGrey)` pair for `todo` is a deliberate light-mode look. Any fix must preserve that. Implementation lives behind `Theme.of(context).brightness` or `colorScheme` tokens, not new constants.
    - No new `AppColors` tokens; existing ones cover all needed states.
    - The Phase 7 `ReservedCheckmarkChip` shipped a clean `colorScheme.onSurface`-in-both-states pattern; the status pill should mirror it.
</background>

<user_flows>
Primary flow:
1. Tester opens a task from the per-event Tasks list → lands on task detail.
2. Status pill ("To Do" / "In Progress" / "Done") is clearly readable against the dark surface — no inverted dark-on-light island.
3. Checklist items show distinct checked/unchecked states with visible ✓ on checked boxes.
4. Completed items have a visible strike-through that scans as "done" without ambiguity.

Alternative flow (light mode):
- Same screen, same pill / checkbox visuals, just inverted contrast — proves the fix didn't regress light mode.

Error flows:
- None new — these are pure presentation changes; no error paths added.
</user_flows>

<requirements>
**Functional:**

1. **Status pill is theme-aware.** `_StatusBadge` in `task_detail_screen.dart:213-241` must pick its `color` / `bgColor` pair from theme tokens (`Theme.of(context).colorScheme`) rather than hard-coded `AppColors.charcoal` / `lightGrey`. The light-mode appearance for the three states stays visually equivalent; dark mode gets analogous colours from the dark scheme.
   - **Status → token mapping** (suggested):
     - `todo`: text = `colorScheme.onSurfaceVariant`, bg = `colorScheme.surfaceContainerHighest`. Both follow the theme.
     - `inProgress`: text = `AppColors.white`, bg = `AppColors.sage` (unchanged — already theme-agnostic).
     - `done`: text = `AppColors.white`, bg = `AppColors.sageDark` (unchanged).

2. **Dark-mode `CheckboxThemeData`** added to `AppTheme.dark()` in `app_theme.dart`. Drives the per-checklist-item state:
   - Filled colour (checked): `colorScheme.primary` (`AppColors.sageLight` in dark scheme).
   - Check icon colour: `colorScheme.onPrimary` (resolves to a colour with contrast against `primary`).
   - Outline colour (unchecked): `colorScheme.outline` or `colorScheme.onSurfaceVariant`.
   - The light theme's `CheckboxThemeData` is unchanged (or also added for parity if missing).

3. **Strikethrough text on completed checklist items** must contrast against the dark surface. Use `Theme.of(context).colorScheme.onSurfaceVariant` (not the default body colour) so completed items read as "done but still legible". The line-through decoration inherits the same colour.

**Error Handling:**

4. Themes that don't define a `CheckboxThemeData` (e.g., a third-party light theme injected via tests) fall back to Material's defaults — no exceptions, no missing-token crashes.

**Edge Cases:**

5. The status pill must render correctly under `textScaler: 1.3`. No overflow, no horizontal clipping.

6. Strike-through pattern stays visible when the checklist item text is very long (multi-line). The line-through decoration follows wrapped lines.

7. Empty checklist (zero items) — no rendering changes needed; the checklist editor already handles that.

**Validation:**

8. No new colour tokens added to `AppColors`. All changes route through `colorScheme` or existing tokens.
</requirements>

<boundaries>
Edge cases:
- Light mode regression: the existing `_StatusBadge` light-mode appearance must look visually equivalent. If a test goldens or visually checks the badge, that check must continue to pass.
- Tester forces a system-level "Increase Contrast" — Material picks up the high-contrast variant automatically through `MediaQuery.highContrastOf(context)`. No special handling needed; just don't hard-code colours that bypass the theme.

Error scenarios:
- None new.

Limits:
- Status pill height stays consistent with the current `padding: EdgeInsets.symmetric(horizontal: md, vertical: xs)` so the AppBar + pill row doesn't reflow.
</boundaries>

<implementation>
Files to create:

- None. All changes are local edits.

Files to modify:

- `lib/app/features/tasks/presentation/task_detail_screen.dart:213-241` — `_StatusBadge.build`: replace the hard-coded tuple with `colorScheme`-derived colours per req 1.

- `lib/app/core/theme/app_theme.dart:88-150` (dark scheme) — add `checkboxTheme: CheckboxThemeData(...)` with the colours from req 2. If light theme has no equivalent, add an analogous one to `AppTheme.light()` so both modes are explicit (current Material defaults may be acceptable for light but parity is cleaner).

- `lib/app/features/tasks/presentation/widgets/checklist_editor.dart:184-196` — completed-item Text style: derive colour from `Theme.of(context).colorScheme.onSurfaceVariant` instead of relying on the default body colour. Carry the same colour into the `TextDecoration.lineThrough` (the line-through decoration uses the Text's colour by default).

Patterns to reuse:

- `ReservedCheckmarkChip` (Phase 7 of the prior plan, 2026-06-08) — `colorScheme.onSurface` for the label in BOTH selected and unselected states. Same shape applies here.
- `DonatedPill` (`lib/app/features/budget/presentation/widgets/donated_pill.dart`) — already-shipped sage-tinted pill that renders correctly in both themes; mirror its `colorScheme`-derived structure for `_StatusBadge`.

What to avoid (and why):

- Don't add new `AppColors` tokens. The existing palette already covers the needed states; new tokens proliferate and create a maintenance burden.
- Don't change the status enum's `.label` extension or any other behaviour outside presentation — pure styling fix.
- Don't introduce per-status `Theme` overrides; centralise via the `_StatusBadge` widget's build method.
- Don't replace `Checkbox` with a custom widget — the existing widget is fine once `CheckboxThemeData` is supplied.
</implementation>

<validation>
Baseline automated coverage:

- **Widget tests** for `_StatusBadge`:
    - Light mode: pump each of the three `TaskStatus` values; assert the rendered `Container.decoration.color` matches the expected token. Asserts the existing light-mode look isn't regressed.
    - Dark mode: same shape; pump each status under `ThemeData.dark(useMaterial3: true)` (or `AppTheme.dark()`); assert the new token colours.
    - Contrast smoke (optional): use the existing `wcag_contrast.dart` helper (`test/app/core/_helpers/wcag_contrast.dart`) from the 2026-06-08 round to assert ≥ 4.5:1 between text and bg in dark mode for the `todo` state.

- **Widget tests** for `_ChecklistItemRow` (or the equivalent under `checklist_editor.dart`):
    - Pump checked + unchecked states under both themes.
    - Assert `Checkbox.fillColor` resolves to `colorScheme.primary` when checked under dark theme.
    - Assert the line-through Text's `style.color` matches `colorScheme.onSurfaceVariant`.

- **Journey tests:** none new required. The existing `tasks_journey_test.dart` exercises checklist interaction and would surface any tap-target regressions.

TDD-first slices:

- Slice 1 (status pill, dark mode `todo`): RED on the existing hard-coded `lightGrey` → GREEN with the `surfaceContainerHighest` swap.
- Slice 2 (status pill, light mode preservation): assert the light theme's `todo` pill still uses the same effective colour family as today.
- Slice 3 (CheckboxThemeData wired): assert the `Checkbox`'s `MaterialStateProperty` resolves to the expected colour in dark mode.
- Slice 4 (strike-through colour): assert completed Text's style.color matches `onSurfaceVariant` in both themes.

Testability seams:

- The `_StatusBadge` widget already takes `status` as a constructor param — pump-time injection is the seam.
- `CheckboxThemeData` is theme-level — tests use `MaterialApp(theme: ..., home: ...)` with each theme variant.

Mocking policy:

- No mocks needed. All changes are pure presentation; `Theme.of(context)` reads the test's injected theme directly.

Test-type mapping:

- Robot / journey: existing journeys cover task-detail interaction; no new journey needed.
- Widget tests: per-state, per-theme assertions in `task_detail_screen_test.dart` (new) and `checklist_editor_test.dart` (extend if exists, else new).
- Unit tests: none — no pure logic added.

Exceptions / deviations:

- The status pill's `done` and `inProgress` states already use theme-agnostic sage/sageDark — those branches don't strictly need a TDD cycle. The plan should still touch them for code-style consistency (single source-of-truth for the colour map).
</validation>

<done_when>

1. All requirements 1-8 implemented and committed on a new feature branch (`fix/task-detail-dark-mode` or similar).
2. `flutter analyze` clean (sole pre-existing `experimental_member_use` warning permitted).
3. `flutter test` passes; new widget tests for `_StatusBadge` + checklist contrast added.
4. Manual visual smoke on iPhone 12 mini sim in DARK mode (the failing case): status pill reads clearly against the navy surface; checked checkboxes show a visible ✓; unchecked checkboxes have a visible outline; completed items have a clear strike-through.
5. Manual visual smoke on iPhone 12 mini sim in LIGHT mode: no regression — pill / checkboxes / strike-through look the same as before.
6. No new `AppColors` tokens introduced.
7. PR description references this spec and includes a Test Plan checklist for both themes.

</done_when>
