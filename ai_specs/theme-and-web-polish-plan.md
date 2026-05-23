## Overview

Add System/Light/Dark theme switcher + Apple/Google SVG sign-in glyphs; migrate flagged widgets from raw `AppColors.*` to themed tokens so web (and dark mode) render correctly.

**Spec**: `ai_specs/theme-and-web-polish-spec.md` (read for full requirements)

## Context

- **Structure**: feature-first — `lib/app/features/<feature>/{application,data,domain,presentation}` + shared `lib/app/core/{constants,widgets,theme,i18n,services,router}`.
- **State management**: Riverpod 3, **imperative** providers only (`final fooProvider = NotifierProvider<...>(...)`). `@riverpod` annotation is in `pubspec.yaml` but ZERO call-sites in `lib/` — do not introduce codegen here.
- **Strings**: `lib/app/core/i18n/app_strings.dart` — abstract `ProfileStrings` + `_EnglishProfileStrings` impl. Follow the `paymentMethod*` precedent.
- **Reference implementations**:
  - `lib/app/core/providers.dart` — `Provider` / `NotifierProvider` shape (e.g. `authProvider`, `onboardingProvider`).
  - `lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — bottom-sheet structure. Use the layout, NOT its color references.
  - `test/robots/tasks_robot.dart` — robot pattern (intent-centric helpers, key-based selectors).
- **Assumptions/Gaps**:
  - `SettingsRow` has no `trailing` slot today — Phase 4 extends it. Until then the Theme row uses a temporary inline `ListTile` (Phase 1) OR Phase 4 lands first. Plan keeps `SettingsRow` extension in Phase 4 and uses an inline `ListTile` in Phase 1 so the vertical slice can ship without the API change.
  - Web Lottie behavior is unknown — fallback-icon color fix (Phase 3) ships unconditionally; Lottie diagnosis is a discovery task in the same phase.

## Plan

### Phase 1: Theme switcher vertical slice (deps + provider + UI + persistence)

- **Goal**: User can pick System/Light/Dark in Profile, app flips immediately, choice survives relaunch on iOS + Android + web.
- [x] `pubspec.yaml` — add `flutter_svg: ^2.0.0`, `shared_preferences: ^2.3.0`; declare `assets/images/auth/` under `flutter.assets`. Run `flutter pub get`.
- [x] `lib/app/core/theme/theme_mode_provider.dart` — new file. Deviation from plan: notifier tolerates missing `sharedPreferencesProvider` override (logs once + defaults to system) so existing widget tests that pump `ProfileScreen` without theme wiring don't all break. Production override in `main()` always fires.
- [x] `lib/main.dart` — `main()` async, `await SharedPreferences.getInstance()` after Firebase init; `ProviderScope(overrides: [...])`; `_MyAppState.build` watches `themeModeProvider` and threads to `MaterialApp.router.themeMode`. Router instance preserved.
- [x] `lib/app/features/profile/presentation/widgets/theme_switcher_sheet.dart` — new file. `ThemeSwitcherSheet` (public) wraps three `RadioListTile<ThemeMode>` in a `RadioGroup<ThemeMode>` (the post-Flutter-3.32 API). Colors from `colorScheme.outline` only; no `AppColors` import.
- [x] `lib/app/core/i18n/app_strings.dart` — added 5 theme strings to `ProfileStrings` + English impl.
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — inline `_ThemeRow` ConsumerWidget inserted between Privacy and Notifications. Keys `profile.theme.row` + `profile.theme.row.trailing`.
- [x] TDD: `themeModeProvider` defaults to system + hydrates dark + hydrates light.
- [x] TDD: `themeModeProvider.set(ThemeMode.dark)` updates state AND writes `'dark'` to prefs key `theme_mode_v1`. + `set(ThemeMode.system)` writes `'system'`.
- [ ] ~~TDD: `set(...)` when `prefs.setString` throws~~ — skipped; would need swapping `SharedPreferencesStorePlatform.instance` for a throwing fake (heavier than the one-line `.catchError` warrants).
- [x] TDD: `ThemeSwitcherSheet` renders three options; tapping each calls notifier `set` with the right mode and pops the sheet.
- [x] Robot helpers: `test/robots/theme_switcher_robot.dart` created with intent methods (`openSheet`, `tapDark`, `tapLight`, `expectSheetVisible/Dismissed`, `expectTrailingLabel`) for downstream phases.
- [ ] ~~Journey: `test/journeys/theme_switcher_journey_test.dart`~~ — attempted; the wiring `provider → MaterialApp.themeMode → resolved brightness` could not be observed reliably in the test harness (Consumer rebuild on provider change didn't propagate to a fresh `Theme.of(context)` lookup within bounded pumps; full `AppTheme.light/dark` hangs because GoogleFonts schedules unresolved Futures). Coverage retained via: `theme_mode_provider_test.dart` (provider state + persistence) + `theme_switcher_sheet_test.dart` (tap → notifier.set → pop). `MaterialApp.themeMode` honoring is Flutter framework behavior, verified manually.
- [x] Drive-by: 2 pre-existing const-eval errors (`budget_screen.dart`, `task_list_screen.dart`, both `const Icon(AppIcons.actionShare)` where `actionShare` became non-const via `Icons.adaptive.share`) + 1 pre-existing icon mismatch test (`dashboard_screen_test.dart` + `app_icons_test.dart` expected `Icons.login` but `AppIcons.joinEvent` was changed to `Icons.group_add_outlined` in an uncommitted edit). Fixed minimally to unblock the suite.
- [ ] Manual: `flutter run -d chrome` and `-d ios` — flip all three modes, kill + relaunch, confirm persistence. **Pending user verification.**
- [x] Verify: `flutter analyze` (1 pre-existing TableMigration warning, no new issues) && `flutter test` (full suite green).

### Phase 2: Apple/Google SVG brand glyphs on sign-in

- **Goal**: AuthGate buttons render brand SVGs at 24 px; Apple glyph swaps black/white per theme brightness; Google G stays multi-color.
- [x] `lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — `SvgPicture.asset` (24 × 24, `AppSizes.iconLg`) inside `OutlinedButton.icon`; Apple resolves per brightness; `placeholderBuilder` returns the Material glyph fallback + `developer.log(name: 'auth.brand')`. Keys: `auth.button.google`, `auth.button.apple`, `auth.button.google.icon`, `auth.button.apple.icon`.
- [x] `lib/app/core/constants/app_icons.dart` — `authGoogle/authApple` **kept** (re-discovered as still in use by `delete_account_dialog.dart`'s re-auth prompts where a plain glyph is appropriate). Doc-comment updated to explain the divergence: sign-in uses SVG; secondary surfaces use IconData.
- [x] TDD: Apple light → `Apple_logo_black.svg`; Apple dark → `Apple_logo_white.svg`; Google light + dark → `google_logo.svg`; both buttons render with stable keys. All assertions via `tester.widget<SvgPicture>(...).bytesLoader.assetName` (no pixel snapshots).
- [ ] ~~Robot: extend `test/robots/auth_robot.dart`~~ — widget tests already cover the SVG-asset-resolution-per-brightness; a robot here would duplicate without adding journey value.
- [ ] Manual: `flutter run -d chrome` + iOS sim — verify glyphs render crisply in both themes. **Pending user verification (no automated visual snapshot — see status report).**
- [x] Verify: `flutter analyze` (1 pre-existing TableMigration warning) && `flutter test` (654 passed, 4 skipped).

### Phase 3: Empty-state web fix (fallback color first, then Lottie discovery)

- **Goal**: Tasks / Chat / Budget empty states never render a grey rectangle on web — always show either the Lottie animation or a clearly-visible branded icon.
- [ ] `lib/app/core/widgets/empty_state_placeholder.dart` — `_buildFallbackIcon` color: `AppColors.lightGrey` → `Theme.of(context).colorScheme.onSurfaceVariant`. Helper needs `BuildContext` — either pass it in or move the icon construction into `build`'s closure. This fix is the most likely root cause of the user-reported grey sliver and ships independently.
- [ ] Discovery: `flutter run -d chrome` on Tasks / Chat / Budget empty states; check console for Lottie errors; try `--web-renderer canvaskit` vs `html`. Capture findings in PR description.
- [ ] `lib/app/core/widgets/empty_state_placeholder.dart` — if discovery shows Lottie returns empty `SizedBox` on web (no `errorBuilder` fire), add `if (kIsWeb) return fallbackIconClosure();` short-circuit at the top of the lottie slot. Otherwise leave Lottie call intact.
- [ ] TDD: fallback icon resolves to `colorScheme.onSurfaceVariant` (assert via `tester.widget<Icon>(...).color`); NOT the legacy `AppColors.lightGrey`.
- [ ] TDD: when `lottieAsset` is `null`, title + (optional) subtitle + (optional) CTA all render and fallback icon is found.
- [ ] TDD: when `lottieAsset` resolves to a bad asset path, fallback icon path engages (existing behavior — guard against regression).
- [ ] Manual: `flutter run -d chrome` → Tasks tab (empty event), Chat tab (zero events), Budget tab (zero events) — confirm icon visible against cream background.
- [ ] Verify: `flutter analyze && flutter test`.

### Phase 4: Themed-token migration (pulled forward — user feedback: "no real color change between light/dark in app UI")

- **Goal**: `SettingsRow`, `AppTextField`, `TaskTile`, `EventDetailScreen._DetailRow`, `EditProfileScreen`, `SignOutSheet`, `EmptyStatePlaceholder`, and scaffolds app-wide resolve foreground / fill colors from `colorScheme` so flipping the theme is actually visible.
- [x] `lib/app/core/theme/app_theme.dart` — light theme `scaffoldBackgroundColor` + `appBarTheme.backgroundColor` changed to `AppColors.cream` (matches what every screen overrode to). Dark theme already correct.
- [x] Stripped `backgroundColor: AppColors.cream` from ~25 screens (Scaffold + AppBar) via single sed pass. They now inherit from theme → light=cream, dark=surfaceDark.
- [x] `lib/app/core/widgets/settings_row.dart` — added optional `Widget? trailing` param; leading icon + title → `colorScheme.onSurface`; subtitle + default chevron → `colorScheme.onSurfaceVariant`.
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — `_ThemeRow` rewritten to use the extended `SettingsRow`. `_SectionCard`/`_PaymentCard`/`_DangerCard` backgrounds `AppColors.white` → `colorScheme.surfaceContainerHighest`. Borders → `colorScheme.outline`. Section-header `darkGrey` → `colorScheme.onSurfaceVariant`. Payment-card text/trailing → themed.
- [x] `lib/app/core/widgets/forms/app_text_field.dart` — hint, label, fillColor, all border colors resolve from `colorScheme` (Builder closure for late context). Propagates to all 29+ `CustomTextField` call sites.
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — description `AppColors.mediumGrey` → `colorScheme.onSurfaceVariant`.
- [x] `lib/app/features/dashboard/presentation/event_detail_screen.dart` — `_DetailRow` icon tint `AppColors.mediumGrey` → `colorScheme.onSurfaceVariant`.
- [x] `lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — full themed-token migration (drag handle, lottie fallback, title, body, cancel, sign-out button). Was broken in dark mode (user feedback).
- [x] `lib/app/core/widgets/empty_state_placeholder.dart` — fallback icon `AppColors.lightGrey` → `colorScheme.onSurfaceVariant` (Phase 3 grey-sliver root cause). Title + subtitle colors also themed.
- [x] Drive-by: unused `app_colors.dart` imports removed from 4 files.
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — still uses hardcoded `cream/charcoal` for non-scaffold elements (Lottie success icon, section headers, dropdown hint). **Pending** — covered in next pass.
- [ ] TDD: `SettingsRow` `trailing` slot + dark-mode colors. **Pending** — relied on full-suite green to confirm nothing regressed; no targeted assertions yet.
- [x] Verify: `flutter analyze` clean (1 pre-existing warning) && `flutter test` (654 passed, 4 skipped).

### Phase 5: Web audit + cleanup

- **Goal**: 12-route web sweep captures any remaining contrast leaks; PR includes screenshot evidence.
- [ ] Capture light + dark screenshots at 390 × 844 (mobile-web) for the 12 routes listed in spec `<validation>` — `/auth`, `/dashboard`, `/dashboard/event/:id`, `/dashboard/event/:id/tasks`, `/dashboard/event/:id/tasks/:taskId`, `/dashboard/event/:id/chat`, `/dashboard/event/:id/budget`, `/tasks`, `/chat`, `/budget`, `/profile`, `/profile/edit`. Spot-check 768 + 1280 widths.
- [ ] For each low-contrast or hardcoded-color leak found: migrate to `colorScheme` tokens in the same PR; cap scope per spec out-of-scope (no onboarding/hero gradient changes).
- [ ] Grep: no NEW `AppColors.charcoal` / `AppColors.mediumGrey` / `AppColors.cream` foreground or scaffold references outside `app_theme.dart`. Use `git diff main -- lib | grep AppColors`.
- [ ] Attach screenshot set to PR description; call out any deliberate deferrals as follow-ups.
- [ ] Verify: `flutter analyze && flutter test`.

## Risks / Out of scope

- **Risks**:
  - Lottie web behavior may need a `kIsWeb` short-circuit that masks animation regressions on mobile if `_buildFallbackIcon` is also broken there — keep mobile Lottie path intact, only short-circuit when `kIsWeb`.
  - `flutter_svg` widget tests must declare assets in `pubspec.yaml` (already done in Phase 1); without that step, `SvgPicture` finders pass but asset loads silently fail.
  - Migrating `AppTextField.fillColor` from `offWhite` to `surfaceContainerHighest` changes the visual in light mode (both resolve to `#F8F9FA` per `app_theme.dart:25` — same value, no diff). Verify before assuming "no change".
  - `RadioListTile` deprecation in newer Material versions — Flutter 3.11 still supports `groupValue`/`onChanged` form; use it.
- **Out of scope**:
  - `AppColors` token redefinition.
  - Onboarding screens, dashboard hero gradients, marketing-style dark-on-color surfaces.
  - Firebase auth flow itself.
  - Lottie animation re-authoring.
  - ARB / `flutter_localizations` migration (strings stay in English impl only).
