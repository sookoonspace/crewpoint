<goal>
Polish CrewPoint's theming and visual contrast so the app reads as first-class on web in both light and dark mode, and so the new sign-in screen uses real Apple/Google brand marks instead of substitute Material glyphs.

Concretely:
- Replace the Material-glyph placeholders on the sign-in screen with the SVG brand marks already shipped under `assets/images/auth/` (Apple `Apple_logo_black.svg` + `Apple_logo_white.svg`, Google `google_logo.svg`).
- Add a user-controlled theme switcher (System/Light/Dark) that persists across launches and drives `MaterialApp.router.themeMode`.
- Tighten both `AppTheme.light()` and `AppTheme.dark()` so they remain visually correct on Flutter Web, where the user is currently seeing:
  - `TaskTile` body text too light to read,
  - `EventDetailScreen` rows too light to read,
  - Empty states for Tasks / Chat inbox / Budget ledger showing a "grayish sliver" instead of the branded Lottie illustration,
  - `EditProfileScreen` cell text + hint text too light,
  - Various other low-contrast leaks (to be found by an explicit web audit).

Users benefit because:
- Sign-in feels trustworthy (real brand glyphs that conform to Apple HIG + Google brand guidelines).
- Web users can read the app — every screen meets WCAG AA against its actual rendered background.
- Dark-mode users get a coherent UI instead of a half-themed app where some surfaces still use hardcoded cream/charcoal.
- The dev team gets a documented "themed-token-only" rule that prevents the next contrast regression.
</goal>

<background>
**Tech stack relevant to this task**
- Flutter `^3.11.5`, Material 3, Riverpod 3, `go_router`.
- Theme entry point: `lib/main.dart` (currently passes `theme:` + `darkTheme:` without setting `themeMode`, so `MaterialApp`'s default `ThemeMode.system` is in effect — the OS preference wins. This spec replaces that default with the user's persisted choice; do NOT "fix" the omission by adding `themeMode: ThemeMode.system` and stopping there).
- Theme definitions: `lib/app/core/theme/app_theme.dart` (two `ThemeData` factories sharing tokens from `app_colors.dart` / `app_typography.dart`).
- No theme persistence today. `flutter_secure_storage: ^9.2.4` is in deps; `shared_preferences` is NOT — adding it is allowed because theme isn't sensitive and `shared_preferences` is the conventional choice for this.
- Sign-in screen uses `IconData` glyphs via `AppIcons.authGoogle` (`Icons.account_circle_outlined` — explicitly flagged TODO) and `AppIcons.authApple` (`Icons.apple`).
- `EmptyStatePlaceholder` already has an `errorBuilder` fallback to a Material icon when Lottie fails; user reports the fallback path is not engaging on web — instead a grey rectangle of `lottieHeight` shows.

**Files to examine (read before changing)**
- `@pubspec.yaml` — confirm Flutter SDK constraint, current dependency floor, and `flutter.assets` list (need to add `assets/images/auth/`).
- `@lib/main.dart` — wire `themeMode` from new provider.
- `@lib/app/core/theme/app_theme.dart` — single source of truth for both themes.
- `@lib/app/core/constants/app_colors.dart` — every color token. Note the per-surface WCAG-AA notes in comments.
- `@lib/app/core/constants/app_icons.dart` — `authGoogle` / `authApple` carry a TODO to swap for SVG assets.
- `@lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — sign-in screen brand buttons.
- `@lib/app/features/auth/presentation/auth_gate_screen.dart` — confirms how `SocialAuthButtons` is composed.
- `@lib/app/core/widgets/empty_state_placeholder.dart` — Lottie loader + icon fallback.
- `@lib/app/features/tasks/presentation/widgets/task_tile.dart` — description uses hardcoded `AppColors.mediumGrey`.
- `@lib/app/features/dashboard/presentation/event_detail_screen.dart` — `_DetailRow` uses `AppColors.mediumGrey` icons; label/value use raw text theme.
- `@lib/app/features/profile/presentation/edit_profile_screen.dart` — hardcoded `AppColors.cream`, `AppColors.offWhite`, `AppColors.charcoal`, raw `bodySmall` for help copy.
- `@lib/app/core/widgets/forms/app_text_field.dart` — hint `mediumGrey`, label `darkGrey`, fill `offWhite`. All three need to resolve from `Theme.of(context).colorScheme` (or `inputDecorationTheme`) to render in dark mode.
- `@lib/app/core/widgets/settings_row.dart` — leading icon `AppColors.charcoal`, title `AppColors.charcoal`, subtitle `AppColors.darkGrey`, trailing chevron `AppColors.mediumGrey`. Every Profile setting renders through this row; it MUST migrate to theme tokens in this PR or the entire Settings section stays light-mode-only. Also: the row has no `trailing` widget slot today — the Theme row in this spec requires adding one (see req 5).
- `@lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — structural reference for the new theme sheet, BUT it hardcodes `AppColors.charcoal` / `lightGrey` / `white`. Do not copy its color references verbatim; resolve from `colorScheme` instead.
- `@lib/app/core/providers.dart` — every existing provider is imperative (`final fooProvider = Provider<...>` / `NotifierProvider<...>`). `riverpod_annotation` is declared in `pubspec.yaml` but has zero call-sites in `lib/` (verified via grep). The new `themeModeProvider` MUST follow the imperative pattern, not `@riverpod`.
- `@lib/app/features/profile/presentation/profile_screen.dart` — destination for the new "Theme" `SettingsRow`.
- `@lib/app/features/tasks/presentation/task_list_screen.dart`, `@lib/app/features/tasks/presentation/my_tasks_screen.dart`, `@lib/app/features/chat/presentation/chat_inbox_screen.dart`, `@lib/app/features/budget/presentation/budget_ledger_screen.dart` — empty-state call sites; confirm they all route through `EmptyStatePlaceholder`.
- `@lib/app/core/i18n/app_strings.dart` (and the `profile` slice) — add Theme labels here.

**Out of scope**
- Replacing or restyling `AppColors`. Tokens stay; usages move from raw `AppColors.*` to `Theme.of(context).colorScheme.*` derivatives where it removes brightness leaks.
- Reworking onboarding, dashboard hero gradients, or marketing-style screens that intentionally paint on a dark gradient. Their hardcoded `AppColors.offWhite` foregrounds are correct.
- Touching `firebase_auth` Google/Apple sign-in flow itself.
</background>

<user_flows>
**Primary flow A — Theme switching**
1. User opens Profile tab.
2. In the Settings section, taps "Theme" row (icon: `Icons.brightness_6_outlined`, value chip showing current mode label).
3. A modal bottom sheet (or `showModalBottomSheet`) lists "System", "Light", "Dark" with a leading radio + brief description for each.
4. User taps an option.
5. Sheet dismisses; `MaterialApp.router` rebuilds with the new `themeMode`; the whole app flips immediately.
6. Choice is persisted (SharedPreferences key `theme_mode_v1`).
7. Killing + relaunching the app preserves the choice.

**Primary flow B — Sign-in with real brand glyphs**
1. Unauthenticated user lands on `AuthGateScreen`.
2. Sees "Continue with Google" and "Continue with Apple" outlined buttons.
3. Google button shows the multi-colour Google "G" SVG (24 px); Apple button shows the Apple glyph SVG (24 px).
4. In dark mode (or when the button's resolved foreground is light), the Apple glyph swaps to `Apple_logo_white.svg`; otherwise `Apple_logo_black.svg`.
5. Google "G" stays multi-colour in both themes (Google brand guidelines forbid recolouring it).
6. Tapping a button performs the existing sign-in flow unchanged.

**Alternative flows**
- **First-launch (no stored preference):** theme provider emits `ThemeMode.system` while persistence read is in flight. No flash: provide an initial value via `ProviderScope.overrides` after the persistence read resolves in `main()` before `runApp(...)`.
- **Web user toggling:** SharedPreferences on web uses `localStorage`; same flow, same persistence.
- **System brightness changes while app is open with `ThemeMode.system`:** the app follows automatically (Flutter built-in).

**Error / recovery flows**
- **Lottie asset fails on web** (current bug): `EmptyStatePlaceholder` engages its existing `errorBuilder` and renders the branded icon fallback. The grey rectangle the user sees today is wrong and must not survive this spec — title + (optional) subtitle + CTA must always render, even when the animation slot is empty.
- **SharedPreferences read fails:** treat as missing preference → `ThemeMode.system`. Log to `developer.log(name: 'theme')`. Never block app start.
- **SharedPreferences write fails:** still apply the mode in-memory; show a SnackBar "Theme preference could not be saved."
- **SVG asset missing at runtime:** `flutter_svg`'s `SvgPicture.asset` throws; wrap in a `placeholderBuilder` falling back to the previous Material glyph so the button is still tappable.
</user_flows>

<requirements>
**Functional**

1. Add `flutter_svg: ^2.0.0` and `shared_preferences: ^2.3.0` to `pubspec.yaml` dependencies. Add `assets/images/auth/` to the `flutter.assets` list.

2. Replace `SocialAuthButtons` glyph rendering: Google button uses `assets/images/auth/google_logo.svg` (multi-colour, never tinted); Apple button uses `Apple_logo_black.svg` when `Theme.of(context).brightness == Brightness.light` and `Apple_logo_white.svg` when `Brightness.dark`. Each rendered at **24 px** (matches `AppSizes.iconLg` and the existing `Icon(size: AppSizes.iconLg)` baseline in this widget).

3. Introduce providers using the imperative pattern that matches `lib/app/core/providers.dart`:
   - `sharedPreferencesProvider` (`Provider<SharedPreferences>`) — declared with a `throw UnimplementedError(...)` body; overridden in `ProviderScope` with the resolved instance from `main()`. This makes test overrides trivial (`overrides: [sharedPreferencesProvider.overrideWithValue(fakePrefs)]`).
   - `themeModeProvider` (`NotifierProvider<ThemeModeNotifier, ThemeMode>`) — `build()` reads the `String?` at key `theme_mode_v1` from `sharedPreferencesProvider` and maps to `ThemeMode`; defaults to `ThemeMode.system` on null or parse failure. Exposes `set(ThemeMode)` which updates state and fire-and-forget writes via the same prefs instance.
   - Do NOT use `@riverpod` annotation or codegen — zero existing providers use it.

4. Wire `MaterialApp.router` in `lib/main.dart` to `themeMode: ref.watch(themeModeProvider)`. `main()` becomes `async`, awaits `SharedPreferences.getInstance()` after `FirebaseService.initialize()`, then constructs `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const MyApp())`. The router instance must not be recreated when theme changes — only the `MaterialApp` rebuild path.

5. Extend `lib/app/core/widgets/settings_row.dart` with an optional `Widget? trailing` parameter. When `trailing` is null, render the existing `Icon(AppIcons.chevronRight)` (back-compat default). When provided, render `trailing` instead. Then add a "Theme" row to the Settings `_SectionCard` in `ProfileScreen`: leading `Icons.brightness_6_outlined`, title "Theme", `trailing` = a small text chip showing the current mode label ("System" / "Light" / "Dark"), tap opens `ThemeSwitcherSheet.show(context)`.

6. `ThemeSwitcherSheet` (public class, modeled on `SignOutSheet`'s structure — but resolving all colors from `Theme.of(context).colorScheme`, NOT copying `SignOutSheet`'s `AppColors.charcoal/lightGrey/white` references) shows three `RadioListTile<ThemeMode>` options: "System — follow device", "Light", "Dark". Tapping one calls `ref.read(themeModeProvider.notifier).set(...)` then pops the sheet.

7. `AppTheme.light()` and `AppTheme.dark()` audit: every theme entry must derive foreground colour from `colorScheme` so a screen that only uses `Theme.of(context).textTheme.*` + default `colorScheme.onSurface` foregrounds renders correctly in both themes. No raw `AppColors.charcoal` for text colours inside theme builders themselves.

8. `TaskTile` description + meta rows: replace `AppColors.mediumGrey` with `Theme.of(context).colorScheme.onSurfaceVariant`. Verify contrast on the actual `Card` background (`colorScheme.surface` in light, `surfaceContainerHighest` in dark).

9. `EventDetailScreen._DetailRow`: replace `AppColors.mediumGrey` icon tint with `colorScheme.onSurfaceVariant`. Label uses `textTheme.labelSmall` (already themed), value uses `textTheme.bodyMedium` (already themed) — no extra change needed.

10. `EditProfileScreen`: stop hardcoding `AppColors.cream` / `AppColors.offWhite` as scaffold/dropdown backgrounds. Use `Theme.of(context).scaffoldBackgroundColor` for the scaffold and let the dropdown inherit `inputDecorationTheme`. Section headers ("Display Name", "Payment Info", etc.) replace `color: AppColors.charcoal` with `Theme.of(context).colorScheme.onSurface`.

11. `AppTextField`: hint text uses `colorScheme.onSurfaceVariant` (currently `AppColors.mediumGrey`, too light on `offWhite` fill); label uses `colorScheme.onSurfaceVariant` (currently `AppColors.darkGrey` — Material 3's canonical "label / secondary" tone is `onSurfaceVariant`, not an opacity stamp on `onSurface`); `fillColor` resolves from `colorScheme.surfaceContainerHighest`; border colours read from `colorScheme.outline`. Also migrate `SettingsRow` from req 5 to the same tokens: leading icon + title → `colorScheme.onSurface`; subtitle + default trailing chevron → `colorScheme.onSurfaceVariant`.

12. **Fix the `EmptyStatePlaceholder` fallback-icon color FIRST** (the most likely root cause of the user-reported "grey sliver"): in `lib/app/core/widgets/empty_state_placeholder.dart:46`, the fallback icon is currently `color: AppColors.lightGrey` (#DFE6E9) — near-invisible against the `AppColors.cream` (#EADDCE) scaffold used by Tasks / Chat / Budget screens. Replace with `Theme.of(context).colorScheme.onSurfaceVariant` (or `colorScheme.primary` if the brand wants extra weight). After this fix, even if Lottie renders nothing the user sees a clearly-visible icon + title + subtitle + CTA.

12a. **Then** investigate Lottie's web behavior (see `<discovery>`). End-state: title + optional subtitle + optional CTA always visible, with either the Lottie animation or the now-visible branded icon fallback. Pick the fix the investigation justifies — likely a `kIsWeb` short-circuit to the icon path.

13. Web audit pass (see `<stages>`): every primary screen renders without low-contrast text, missing background, or hardcoded-light-mode leak in either theme.

**Error Handling**

14. `SharedPreferences` get/set failures inside `themeModeProvider` are caught + logged via `dart:developer.log(name: 'theme')`. Reads default to `ThemeMode.system`. Writes that fail surface a non-blocking SnackBar (`Theme preference could not be saved.`) but the in-memory state still flips.

15. Missing SVG asset (asset bundle returns 404 / decode fails): each SVG is wrapped with a `placeholderBuilder` that returns a neutral Material icon glyph fallback so the button stays tappable. Use `Icons.account_circle_outlined` for Google and `Icons.apple` for Apple (these match the glyphs the buttons rendered before this PR). `AppIcons.authGoogle` / `AppIcons.authApple` may be deleted from `app_icons.dart` once the SVG swap lands — the fallbacks reference `Icons.*` directly so the `AppIcons` entries are no longer needed. Log the failure once per asset via `developer.log(name: 'auth.brand')`.

16. `EmptyStatePlaceholder`'s `errorBuilder` already exists. Verify it actually fires on web Lottie failures by adding a single test that renders the widget with an explicit bad asset and asserts the fallback icon is found.

**Edge Cases**

17. Theme switcher invoked while another modal is open: not possible from the Profile tab path; spec ignores it.

18. SafeArea + sheet content: the theme switcher sheet runs through `SafeArea` (bottom inset) so the iOS home indicator doesn't overlap the "Dark" row.

19. Dropdown fields in `EditProfileScreen` currently override `fillColor` per call site. After fix, dropdowns inherit `inputDecorationTheme` from the resolved theme — confirm the prefixIcon tint still reads (current code passes `color: AppColors.charcoal` to dropdown items; replace with `colorScheme.onSurface`).

20. The "Edit Profile" success screen uses `Lottie.asset(AppAssets.lottieSuccess)`. If web Lottie diagnosis lands a `kIsWeb` fallback policy, apply the same fallback here.

21. Apple HIG: do NOT recolour the Apple glyph beyond black/white. Do NOT add a drop shadow. The white variant is for dark surfaces only.

22. Google brand: do NOT recolour the multi-colour G. Do NOT change its aspect ratio.

**Validation**

23. Test seam: `ThemeModeNotifier.set(ThemeMode)` is non-`async`; persistence is fire-and-forget (`unawaited(prefs.setString(...))`) so the UI doesn't await disk. Tests use vanilla `ProviderContainer` (matching every other test in this repo — `riverpod_test` is NOT a dependency) with `overrides: [sharedPreferencesProvider.overrideWithValue(fakePrefs)]`.

24. Test seam: `sharedPreferencesProvider` is declared with `throw UnimplementedError(...)` so any consumer that forgets the override fails loudly. Production overrides it in `main()` with `SharedPreferences.getInstance()`; tests override it with an in-memory `SharedPreferences` (via `SharedPreferences.setMockInitialValues({...})` + `SharedPreferences.getInstance()`).

25. Test seam: `ThemeSwitcherSheet` is a public class (no leading underscore) with a static `show(context)` and a public `build` body, so widget tests can render it directly via `pumpWidget(...)` instead of always opening it through Profile.

26. Stable selectors:
    - `Key('profile.theme.row')` on the new SettingsRow.
    - `Key('profile.theme.row.trailing')` on the value chip inside that row.
    - `Key('profile.theme.sheet')` on the sheet root.
    - `Key('profile.theme.sheet.option.system')`, `…light`, `…dark` on each option tile.
    - `Key('auth.button.google')` and `Key('auth.button.apple')` on each `OutlinedButton`.
    - `Key('auth.button.google.icon')` / `Key('auth.button.apple.icon')` on the `SvgPicture` so tests can assert the right asset path was used (via the `SvgPicture` finder's source).

27. SVG asset-bundle setup in widget tests: `SvgPicture.asset` resolves through the standard Flutter test asset bundle once the asset is declared in `pubspec.yaml`. Tests assert the right asset path was chosen by reading `tester.widget<SvgPicture>(finder).bytesLoader` (or equivalent) and matching the asset name — do NOT pixel-snapshot.
</requirements>

<boundaries>
**Edge cases**
- First-run before SharedPreferences hydrates: app starts in `ThemeMode.system`. Persistence must be read in `main()` before `runApp(...)` to avoid a one-frame flash in the wrong theme.
- User toggles OS dark mode while app is open with `ThemeMode.system`: Flutter handles automatically; nothing custom needed.
- Sign-in screen in dark mode: Apple glyph swaps to white; Google G stays multicolour; button background follows `OutlinedButton` theme (border + onSurface text).
- Edit Profile rendered in dark mode: dropdown items + prefix icons read against `surfaceContainerHighest`, not `cream`/`offWhite`.

**Error scenarios**
- SharedPreferences disk error: fall back to `ThemeMode.system`, log once. SnackBar on write failure only.
- SVG asset missing: render Material icon glyph fallback; do not break the button.
- Lottie asset missing or unsupported on web: render icon fallback. The grey-sliver behaviour is a bug and must not survive.
- Network image inside `_HeroCard` avatar: out of scope — already has a placeholder widget.

**Limits**
- Theme switcher is single-select (radio semantics). No "Other" custom mode, no per-screen overrides.
- SVG button icon is fixed at 24 px width (matches `AppSizes.iconLg`). Do not scale per text scale factor (icon doesn't communicate content — text label does).
- Web audit screenshots cover: 390 × 844 (mobile-web), 768 × 1024 (tablet), 1280 × 800 (desktop). Both themes. The 12 routes are listed explicitly in `<validation>` "Manual verification"; 12 × 2 themes × 3 breakpoints = 72 frames; spot-check, don't pixel-snapshot.
</boundaries>

<implementation>
**Files to create**
- `lib/app/core/theme/theme_mode_provider.dart` — imperative `final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);` + `final sharedPreferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('Override in main() with the resolved instance.'));`. `ThemeModeNotifier.build()` reads the string at key `theme_mode_v1` via `ref.read(sharedPreferencesProvider)` and parses to `ThemeMode` (default `system`). `set(ThemeMode mode)` updates `state` and `unawaited(prefs.setString(...))`.
- `lib/app/features/profile/presentation/widgets/theme_switcher_sheet.dart` — public `ThemeSwitcherSheet` class with `static Future<void> show(BuildContext)` and a `build(...)` body of three `RadioListTile<ThemeMode>`s. ALL colors resolved from `Theme.of(context).colorScheme.*` — do not import `AppColors` here.

**Files to modify**
- `pubspec.yaml` — add `flutter_svg: ^2.0.0` and `shared_preferences: ^2.3.0`; add `assets/images/auth/` to `flutter.assets`.
- `lib/main.dart` — make `main()` async; after `FirebaseService.initialize()`, `final prefs = await SharedPreferences.getInstance();`; pass via `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const MyApp())`. In `_MyAppState.build`, `final themeMode = ref.watch(themeModeProvider);` then `MaterialApp.router(..., themeMode: themeMode, ...)`. Do NOT add `themeMode` to `_RouterRefresh` — theme rebuilds `MaterialApp` directly; router refresh stays for auth/onboarding.
- `lib/app/core/theme/app_theme.dart` — confirm both factories are colour-scheme-driven; no behavioural change required if audit clean, but document each token's WCAG-AA target in comments (extends the existing convention).
- `lib/app/core/constants/app_icons.dart` — delete `authGoogle` and `authApple` once SVG swap lands. Fallback in `social_auth_buttons.dart` references `Icons.account_circle_outlined` / `Icons.apple` directly (see req 15) so these tokens become dead.
- `lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — replace `Icon(icon, size: AppSizes.iconLg)` with `SizedBox(width: 24, height: 24, child: SvgPicture.asset(..., placeholderBuilder: (_) => Icon(Icons.X)))`. Thread `Theme.of(context).brightness` for Apple glyph selection.
- `lib/app/core/widgets/empty_state_placeholder.dart` — (a) `_buildFallbackIcon` color: `AppColors.lightGrey` → `Theme.of(context).colorScheme.onSurfaceVariant` (note: needs `BuildContext` — either pass it in or convert the helper to a closure inside `build`). (b) Investigation outcome from `<discovery>` lands here (likely a `kIsWeb` short-circuit that calls the fallback path directly). End-state: title + subtitle + CTA always visible against a visible illustration or icon.
- `lib/app/core/widgets/settings_row.dart` — add optional `Widget? trailing` constructor param. When `null`, render `Icon(AppIcons.chevronRight, color: Theme.of(context).colorScheme.onSurfaceVariant)` (back-compat). When provided, render `trailing`. Migrate leading icon + title color to `colorScheme.onSurface`; subtitle color to `colorScheme.onSurfaceVariant`. Update the existing `Key('settings.row.subtitle')` test to reflect themed color (or assert the style, not the literal).
- `lib/app/features/tasks/presentation/widgets/task_tile.dart` — replace `AppColors.mediumGrey` body-text colour with `Theme.of(context).colorScheme.onSurfaceVariant`.
- `lib/app/features/dashboard/presentation/event_detail_screen.dart` — replace `AppColors.mediumGrey` icon tint with `colorScheme.onSurfaceVariant`.
- `lib/app/features/profile/presentation/edit_profile_screen.dart` — replace hardcoded `AppColors.cream` / `AppColors.offWhite` / `AppColors.charcoal` with theme tokens; drop the inline `DropdownButtonFormField.decoration` overrides so they inherit `inputDecorationTheme`.
- `lib/app/core/widgets/forms/app_text_field.dart` — hint → `onSurfaceVariant`, label → `onSurfaceVariant`, fillColor → `surfaceContainerHighest`, border → `outline`. This is the canonical text field — fix here propagates to the 29+ legacy `CustomTextField` call sites for free.
- `lib/app/features/profile/presentation/profile_screen.dart` — insert the new "Theme" `SettingsRow` above "Notifications" in the existing Settings `_SectionCard`. Wire `onTap: () => ThemeSwitcherSheet.show(context)`; `trailing:` a small `Text` chip reading the current mode label from `ref.watch(themeModeProvider)`.
- `lib/app/core/i18n/app_strings.dart` — add Theme strings to `ProfileStrings`: `themeRowTitle` ("Theme"), `themeModeSystem` ("System"), `themeModeLight` ("Light"), `themeModeDark` ("Dark"), `themeModeSystemSubtitle` ("Follow device"). Add the English impl in `_EnglishProfileStrings` (file already follows this pattern — see how `paymentMethod*` strings are declared + implemented).
- *(Optional but encouraged)* `lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — drive-by migrate hardcoded `AppColors.charcoal/lightGrey/white` to themed tokens so dark mode renders correctly. Same surface family as the new theme sheet; touching it now is cheap.

**Patterns to follow**
- Riverpod 3 imperative providers — `final fooProvider = Provider<...>` / `NotifierProvider<...>`. Despite `riverpod_annotation` being in `pubspec.yaml`, ZERO call-sites in `lib/` use `@riverpod`; do NOT introduce code-gen with this PR.
- Bottom-sheet pattern: `SignOutSheet.show(...)` is the structural template (drag handle + Lottie + title + body + button row, `MediaQuery.viewPaddingOf(context).bottom` for safe-area). Copy the *layout*, but resolve all colors from `Theme.of(context).colorScheme.*` — `SignOutSheet`'s color references are themselves a known leak.
- `SettingsRow` does NOT support a trailing widget today (it hardcodes `chevronRight`); this PR adds the `trailing` slot before using it (see req 5 + the modify list).
- For SVG sizing inside `OutlinedButton.icon`, wrap with `SizedBox(width: 24, height: 24, child: SvgPicture.asset(...))` — `OutlinedButton.icon` aligns by widget bounds, not glyph metrics.

**What to avoid and why**
- Do NOT recreate the `GoRouter` instance when theme changes. The existing `_RouterRefresh` pattern is for auth/onboarding state, not theme. Theme rebuilds happen via `MaterialApp` re-render — the router lives on.
- Do NOT colour the Google "G". Brand guidelines forbid it and changes the perceived authenticity of the button.
- Do NOT replace `AppColors` tokens with Material defaults. The tokens are correct; the bug is that screens reach for them directly instead of via the theme.
- Do NOT introduce a `Provider<ThemeData>` that screens read from; theme already flows through `Theme.of(context)`.
- Do NOT add `flutter_secure_storage` for theme persistence — overkill, slower, and surfaces a biometric prompt on some platforms.
</implementation>

<discovery>
**First** apply req 12's fallback-icon color fix unconditionally — that resolves the most likely root cause regardless of Lottie behavior.

Then investigate Lottie's web behavior to decide whether to keep animations on web at all:

1. What does `lottie: ^3.3.1` do on `kIsWeb` when `Lottie.asset(...)` is called with an asset that's also listed in `pubspec.yaml`? Does it render? Throw? Return an empty `SizedBox`?
2. Are all six animation JSONs declared in `lib/app/core/constants/app_assets.dart` (`lottieError`, `lottieEmptyState`, `lottieLoading`, `lottieSignOut`, `lottieSuccess`, `lottieProfile`) valid Lottie files? Run them through `lottiefiles.com` validator or `flutter run -d chrome` locally and check the console.
3. Is the `errorBuilder` actually fired on web load failures, or does Lottie silently render nothing? If silent: we need an explicit `kIsWeb` guard inside `EmptyStatePlaceholder` that calls the fallback-icon path directly when web rendering is unreliable.
4. Does swapping the `flutter run` web renderer (auto → canvaskit → html) change behaviour? CrewPoint's `web/index.html` likely defaults to auto.

Capture the answer in the PR description so the next person knows whether the fix is "web fallback to icon" or "Lottie config tweak."
</discovery>

<stages>
**Stage 1 — Dependencies + theme provider scaffolding**
- Add `flutter_svg`, `shared_preferences` to `pubspec.yaml`; declare `assets/images/auth/`.
- Create `themeModeProvider` + persistence service.
- Wire `main.dart` to read SharedPreferences before `runApp` and pass `themeMode` to `MaterialApp.router`.
- Verify by toggling the provider in a test and asserting `MaterialApp` rebuilds with the new `themeMode`.

**Stage 2 — Theme switcher UI**
- Create `_ThemeSwitcherSheet`.
- Add "Theme" SettingsRow to Profile.
- Add Theme strings to `app_strings.dart`.
- Verify by manually toggling all three options on iOS simulator, Android emulator, and `chrome` — full-app flip is immediate.

**Stage 3 — Brand glyphs on sign-in**
- Replace `Icon` calls in `SocialAuthButtons` with `SvgPicture.asset`.
- Thread brightness for Apple glyph.
- Add the test selectors listed in req 26.
- Verify by viewing the auth gate in both themes on web; capture screenshots.

**Stage 4 — Empty-state web fix**
- Land the fallback-icon color fix (req 12) FIRST — this almost certainly resolves the user-reported grey-sliver bug on its own.
- Execute the discovery checklist; land the Lottie fix the investigation justifies.
- Verify by running Tasks / Chat inbox / Budget ledger on `chrome` with empty data sources — illustration or branded icon must render; never a grey rectangle.

**Stage 5 — Themed-token migration on flagged widgets**
- `SettingsRow` (add `trailing` param; migrate colors). All Profile rows depend on this.
- `TaskTile` (description + meta).
- `EventDetailScreen._DetailRow`.
- `EditProfileScreen` (scaffold, dropdowns, section headers).
- `AppTextField` (hint, label, fill, border).
- *(Optional)* `SignOutSheet` drive-by.
- Verify by reviewing each screen in light + dark + web; compare to the audit screenshots.

**Stage 6 — Web audit + cleanup**
- For each screen in the audit list (see boundaries), capture a screenshot at 390/768/1280 in both themes.
- Note any remaining low-contrast text or hardcoded-colour leak; fix by routing through the theme.
- Attach the screenshot diff to the PR.

Each stage must compile, pass `flutter analyze`, and not regress existing tests before the next begins.
</stages>

<validation>
**Baseline automated coverage outcomes**

- Logic / state:
  - `themeModeProvider` test (vanilla `ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(fakePrefs)])` — `riverpod_test` is NOT a dep): hydrates from injected fake `SharedPreferences`; `set(ThemeMode.dark)` updates state AND writes to prefs.
  - Persistence error path test: fake `SharedPreferences` throws on `setString` → state still flips, error is logged.

- UI behaviour (widget tests):
  - `SocialAuthButtons` renders `SvgPicture` finders for both buttons; Apple glyph picks `_black.svg` under light theme and `_white.svg` under dark theme (use `MaterialApp(theme:..., darkTheme:..., themeMode:...)` wrapping). Assert via `tester.widget<SvgPicture>(finder).bytesLoader` / `assetName`, not pixel snapshots.
  - `ThemeSwitcherSheet` shows three options; tapping each calls `set(...)` with the expected mode and pops the sheet.
  - `EmptyStatePlaceholder` (a) renders title + subtitle + CTA when Lottie asset is null; (b) renders the fallback icon with a `colorScheme.onSurfaceVariant` tone (NOT the legacy `AppColors.lightGrey`); (c) icon path also fires when `lottieAsset` is provided but errors via `errorBuilder`.
  - `EditProfileScreen` widget test in dark theme: hint text colour resolved from `colorScheme.onSurfaceVariant` (assert via `Text` style probe), not the legacy `mediumGrey`.
  - `SettingsRow` widget test: when `trailing` is null, renders `chevronRight`; when provided, renders the supplied widget; in dark theme, leading icon + title use `colorScheme.onSurface`.

- Critical journeys (robot tests in `test/robots/`):
  - `themeSwitcherRobot`: launch app → open Profile → tap Theme row → assert sheet visible → tap "Dark" → assert sheet dismissed → assert `MaterialApp` themeMode == dark → restart app harness → assert dark persists.
  - `signInRobot`: render `AuthGateScreen` in light + dark → assert Google + Apple SVG buttons exist with the right asset paths.

**TDD expectations**
- Apply the `flutter-tdd` skill for new logic (`themeModeProvider`, persistence wrapper). For each behaviour:
  1. **RED** — write a single failing test asserting one observable outcome (initial state, hydrate from prefs, persist on set, persist failure logged).
  2. **GREEN** — write the minimum implementation to pass it.
  3. **REFACTOR** — tighten naming + dedupe.
  No batched test suites before implementation. Each cycle commits independently.
- Inject `SharedPreferences` via the provider boundary (do not call `SharedPreferences.getInstance()` from inside the notifier in production after the initial hydrate — pass the resolved instance in).

**Robot testing expectations**
- Apply the `flutter-robot-testing` skill before writing the theme-switcher and sign-in robots.
- Selectors listed in req 26 are the only stable handles tests may use.
- Deterministic seams: a fake SharedPreferences injected via `ProviderScope.overrides`; no real disk I/O; no real Firebase init in these widget tests.

**Default test-split**
- Robot: theme-switcher journey, sign-in screen brand-glyph render.
- Widget: `EmptyStatePlaceholder` fallback color + Lottie behaviour, `AppTextField` themed colours, `SettingsRow` `trailing` slot + dark-mode colors, `ThemeSwitcherSheet` option handling, `SocialAuthButtons` brand glyph picker.
- Unit: `themeModeProvider` notifier (hydrate + set + persist-error path).

**Manual verification (no automation substitute exists)**
- Run `flutter run -d chrome` and visit the 12 routes that drive the audit count in `<boundaries>`:
  1. `/auth`
  2. `/dashboard`
  3. `/dashboard/event/:id` (event detail)
  4. `/dashboard/event/:id/tasks` (event tasks)
  5. `/dashboard/event/:id/tasks/:taskId` (task detail)
  6. `/dashboard/event/:id/chat` (event chat)
  7. `/dashboard/event/:id/budget` (event budget)
  8. `/tasks` (cross-event My Tasks)
  9. `/chat` (cross-event inbox)
  10. `/budget` (cross-event ledger)
  11. `/profile`
  12. `/profile/edit`
- Capture light + dark screenshots; attach to PR.
- Verify on iOS simulator + Android emulator that the brand glyphs render at 24 px with the right SVG path resolved per theme brightness.
- Verify on `chrome` that empty-state screens show the Lottie or the (now-visible) branded icon — never a grey rectangle.
</validation>

<done_when>
1. `flutter pub get` succeeds with the new `flutter_svg` + `shared_preferences` dependencies; `flutter analyze` is clean.
2. `flutter test` passes, including:
   - `themeModeProvider` hydration + persist + error-path tests.
   - `_ThemeSwitcherSheet` option-tap tests.
   - `SocialAuthButtons` SVG-asset-path-per-brightness tests.
   - `EmptyStatePlaceholder` fallback test.
   - `AppTextField` themed-colour test in dark mode.
   - Theme-switcher + sign-in robot journey tests.
3. Sign-in screen renders the multi-colour Google G and the Apple glyph at 24 px (black on light theme, white on dark theme) on iOS, Android, and Chrome.
4. Profile tab shows a "Theme" row that opens the chooser sheet; selection survives kill + relaunch on all three platforms.
5. Tasks, Chat inbox, Budget ledger empty states render either the branded Lottie or the branded icon fallback on Chrome — never a grey rectangle.
6. `TaskTile` description, `EventDetailScreen` rows, `EditProfileScreen` cells + hint text all meet WCAG AA on their actual rendered background, in both light and dark theme, on Chrome.
7. Web audit screenshots (12 screens × light + dark × at least one viewport) attached to the PR description with any remaining gaps explicitly called out as out-of-scope follow-ups.
8. No new raw `AppColors.charcoal` / `AppColors.mediumGrey` / `AppColors.cream` references introduced in this PR for foreground text or scaffold colours outside the theme builders themselves (grep enforced in PR review).
</done_when>
