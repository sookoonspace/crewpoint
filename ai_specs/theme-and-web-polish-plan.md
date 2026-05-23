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
- [ ] `pubspec.yaml` — add `flutter_svg: ^2.0.0`, `shared_preferences: ^2.3.0`; declare `assets/images/auth/` under `flutter.assets`. Run `flutter pub get`.
- [ ] `lib/app/core/theme/theme_mode_provider.dart` — new file:
  - `final sharedPreferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('Override in main()'));`
  - `class ThemeModeNotifier extends Notifier<ThemeMode>` — `build()` reads `theme_mode_v1` via `ref.read(sharedPreferencesProvider)`, parses to `ThemeMode` (default `system`); `void set(ThemeMode mode)` updates state + `unawaited(prefs.setString(...))` with `try/catch` + `developer.log(name: 'theme')`.
  - `final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);`
- [ ] `lib/main.dart` — make `main()` async, `await SharedPreferences.getInstance()` after `FirebaseService.initialize()`; wrap with `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const MyApp())`. In `_MyAppState.build`, `final themeMode = ref.watch(themeModeProvider);` then pass `themeMode:` to `MaterialApp.router`. Do NOT route theme through `_RouterRefresh`.
- [ ] `lib/app/features/profile/presentation/widgets/theme_switcher_sheet.dart` — new file. Public `ThemeSwitcherSheet` with `static Future<void> show(BuildContext)` + `build` body of three `RadioListTile<ThemeMode>` (`system` / `light` / `dark`). Keys: `profile.theme.sheet`, `profile.theme.sheet.option.system|light|dark`. Tap calls `ref.read(themeModeProvider.notifier).set(...)` then `Navigator.pop(context)`. All colors via `Theme.of(context).colorScheme.*` — no `AppColors` import.
- [ ] `lib/app/core/i18n/app_strings.dart` — add `themeRowTitle`, `themeModeSystem`, `themeModeLight`, `themeModeDark`, `themeModeSystemSubtitle` to `ProfileStrings` + `_EnglishProfileStrings`.
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — insert a `ListTile` (NOT `SettingsRow` yet — Phase 4 extends it) above "Notifications" in Settings `_SectionCard`: leading `Icons.brightness_6_outlined`, title from strings, trailing small `Text` chip showing `ref.watch(themeModeProvider)` label, `onTap: () => ThemeSwitcherSheet.show(context)`. Key: `profile.theme.row`, trailing key `profile.theme.row.trailing`.
- [ ] TDD: `themeModeProvider` hydrates from injected fake `SharedPreferences` and emits the stored `ThemeMode`.
- [ ] TDD: `themeModeProvider.set(ThemeMode.dark)` updates state AND writes `'dark'` to prefs key `theme_mode_v1`.
- [ ] TDD: `set(...)` when `prefs.setString` throws — state still flips, error logged (no rethrow).
- [ ] TDD: `ThemeSwitcherSheet` renders three options; tapping each calls notifier `set` with the right mode and pops the sheet.
- [ ] Robot: `test/robots/theme_switcher_robot.dart` + `test/robots/theme_switcher_robot_test.dart` — open Profile → tap `profile.theme.row` → assert sheet visible → tap "Dark" → assert sheet dismissed → assert `MaterialApp.themeMode == ThemeMode.dark`. Use `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(fakePrefs)])` via `SharedPreferences.setMockInitialValues({})`.
- [ ] Manual: `flutter run -d chrome` and `-d ios` — flip all three modes, kill + relaunch, confirm persistence.
- [ ] Verify: `flutter analyze && flutter test`.

### Phase 2: Apple/Google SVG brand glyphs on sign-in

- **Goal**: AuthGate buttons render brand SVGs at 24 px; Apple glyph swaps black/white per theme brightness; Google G stays multi-color.
- [ ] `lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — replace `Icon(icon, size: AppSizes.iconLg)` with `SizedBox(width: 24, height: 24, child: SvgPicture.asset(asset, placeholderBuilder: (_) => Icon(fallback)))`. Apple: `Theme.of(context).brightness == Brightness.dark ? 'assets/images/auth/Apple_logo_white.svg' : 'assets/images/auth/Apple_logo_black.svg'`, fallback `Icons.apple`. Google: `'assets/images/auth/google_logo.svg'`, fallback `Icons.account_circle_outlined`. Keys: `auth.button.google`, `auth.button.apple`, `auth.button.google.icon`, `auth.button.apple.icon`.
- [ ] `lib/app/core/constants/app_icons.dart` — delete `authGoogle` + `authApple` entries (no longer referenced).
- [ ] TDD: under light theme, Apple `SvgPicture` resolves to `Apple_logo_black.svg`; under dark theme, `Apple_logo_white.svg` (assert via `tester.widget<SvgPicture>(finder).bytesLoader` asset name — no pixel snapshot).
- [ ] TDD: Google `SvgPicture` always resolves to `google_logo.svg` regardless of brightness.
- [ ] Robot: extend `test/robots/auth_robot.dart` (create if missing) — render `AuthGateScreen` in light + dark; assert both brand buttons exist with the right asset paths.
- [ ] Manual: `flutter run -d chrome` + iOS sim — verify glyphs render crisply in both themes.
- [ ] Verify: `flutter analyze && flutter test`.

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

### Phase 4: Themed-token migration

- **Goal**: `SettingsRow`, `AppTextField`, `TaskTile`, `EventDetailScreen._DetailRow`, `EditProfileScreen` all resolve foreground / fill colors from `colorScheme` so dark mode + web render correctly.
- [ ] `lib/app/core/widgets/settings_row.dart` — add optional `Widget? trailing` constructor param; render `trailing ?? Icon(AppIcons.chevronRight, color: colorScheme.onSurfaceVariant)`. Leading icon + title → `colorScheme.onSurface`; subtitle → `colorScheme.onSurfaceVariant`.
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — swap the Phase 1 inline `ListTile` for the now-extended `SettingsRow` (key + behavior unchanged).
- [ ] `lib/app/core/widgets/forms/app_text_field.dart` — hint → `colorScheme.onSurfaceVariant`; label → `colorScheme.onSurfaceVariant`; `fillColor` → `colorScheme.surfaceContainerHighest`; borders → `colorScheme.outline`; focused border → `colorScheme.primary`.
- [ ] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — description + meta `AppColors.mediumGrey` → `Theme.of(context).colorScheme.onSurfaceVariant`.
- [ ] `lib/app/features/dashboard/presentation/event_detail_screen.dart` — `_DetailRow` icon tint `AppColors.mediumGrey` → `Theme.of(context).colorScheme.onSurfaceVariant`.
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — `backgroundColor: AppColors.cream` → `Theme.of(context).scaffoldBackgroundColor`; drop inline `DropdownButtonFormField.decoration` overrides (let `inputDecorationTheme` apply); section header `color: AppColors.charcoal` → `Theme.of(context).colorScheme.onSurface`; success screen + AppBar mirror the same change.
- [ ] *(Optional drive-by)* `lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — migrate hardcoded `charcoal/lightGrey/white` to themed tokens.
- [ ] `lib/app/core/theme/app_theme.dart` — audit pass; confirm both factories are colorScheme-driven; document any per-token AA notes that were added or moved.
- [ ] TDD: `SettingsRow` with `trailing: null` renders `chevronRight`; with `trailing: SizedBox(key: K)` renders the supplied widget.
- [ ] TDD: `SettingsRow` in dark theme — leading icon + title use `colorScheme.onSurface` (style probe).
- [ ] TDD: `AppTextField` in dark theme — hint style uses `colorScheme.onSurfaceVariant` (style probe).
- [ ] Manual: open Tasks list, Event detail, Edit Profile, Profile (Settings rows) in both themes on `chrome` — confirm contrast.
- [ ] Verify: `flutter analyze && flutter test`.

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
