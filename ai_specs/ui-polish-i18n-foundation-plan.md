## Overview

UI hardening pass: branded web favicon, web-friendly auth-gate layout, WCAG-grade contrast across `AppColors`, and an `AppStrings` constants file laying the foundation for ARB-based localization (Spanish / Hindi / French follow as separate work).

## Context

- **Structure**: feature-first under `lib/app/features/`; theme + design tokens in `lib/app/core/{constants,theme}/`.
- **State management**: Riverpod 3 (no app-state changes in this plan; UI/theme/strings only).
- **Reference implementations**:
  - `lib/app/core/constants/app_colors.dart` — palette source of truth (cream / sage / terracotta / charcoal).
  - `lib/app/core/constants/app_typography.dart` — Poppins display + Inter body via `google_fonts`; single foreground color today (no role-based color tokens).
  - `lib/app/core/theme/app_theme.dart` — Material 3 `ColorScheme.light/dark`; `ElevatedButton` is sage-on-white (likely contrast-fine), `OutlinedButton` inherits default theme outline (potential fail on cream surfaces).
  - `lib/app/features/auth/presentation/auth_gate_screen.dart` — `SafeArea > SingleChildScrollView > Column` with no max-width → buttons + text fields stretch full-viewport on web.
  - `web/favicon.png` is 16×16 default-Flutter art (917 B); `web/icons/Icon-192.png` is the actual CrewPoint launcher.
  - `web/index.html` already has `<title>CrewPoint</title>` + `apple-mobile-web-app-title` (rebranded in earlier phase) — only the favicon image is wrong.
- **String volume**: ~276 `Text(` call sites in `lib/`. Phase 3 scopes the extraction to **auth feature only** as the proving slice; other features tracked in `todo.md`.
- **Localization choice**: ship a **`context.strings.auth.signIn`** call-site shape from day one — backed by a hand-written English `_EnglishStrings()` impl today, swappable for `AppLocalizations.of(context)!` later. Static `AppStrings.auth.signIn` is rejected because the eventual ARB migration would require touching every call site to inject `BuildContext`; the extension hides that future change inside one file. Phase 3 wires the extension; ARB pipeline is a follow-up.
- **Assumptions/Gaps**:
  - User is fine with English-only V1; localization wiring is foundation work, not translation delivery.
  - Auth-gate stretch is reproducible on Chrome at desktop widths; confirmed via the responsive shell stack.
  - WCAG AA (4.5:1 for body text, 3:1 for large text / UI components) is the target; AAA isn't required.

## Plan

### Phase 1: Web brand polish + auth-gate layout

- **Goal**: web tab shows the CrewPoint icon; auth gate buttons + text fields are bounded to a readable column on wide viewports.
- [x] `web/favicon.png` — regenerated from `assets/icons/launcher_icon.png` at 32×32 via `sips` (replaced the 16×16 default-Flutter art).
- [x] `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-{192,512}.png` — regenerated from the same launcher source so the manifest icons match the web favicon (the previous files were thin; the regenerated set is 15.5 KB / 49 KB / etc., consistent with the CrewPoint launcher branding).
- [x] `web/index.html` — already correct; no change.
- [x] `lib/app/features/auth/presentation/auth_gate_screen.dart` — body's `Column` now lives inside `Center > ConstrainedBox(key: Key('auth.gate.column'), maxWidth: 480)`. Below 480-px viewports the column fills the available width; above it the column centers + clamps so buttons + text fields stop stretching edge-to-edge on web.
- [x] TDD: `auth_gate_screen_layout_test.dart` pumps at 1280×800 (desktop), asserts `tester.getSize(find.byKey('auth.gate.column')).width <= 480`.
- [x] TDD: same file pumps at 375×812 (iPhone), asserts the column fills the viewport (`> 300 && < 375`).
- [ ] Manual smoke (web): `flutter build web --release --dart-define=FLAVOR=dev && firebase deploy --only hosting:crewpoint-dev`; open in Chrome at 1280 width — confirm tab shows the CrewPoint icon and the auth gate isn't stretched. Hard-refresh (`Cmd+Shift+R`) to bust the favicon cache. **Manual user step**
- [x] Verify: `flutter analyze` clean; `flutter test` 183 pass + 4 screenshot suites skipped

### Phase 2: Color contrast + typography readability

- **Goal**: every foreground/background pair the app uses meets WCAG AA (4.5:1 body, 3:1 large/UI). Typography gets a polish pass — line height + letter-spacing tuning.
- [x] `lib/app/core/constants/wcag.dart` — `contrastRatio(Color a, Color b)` plus `kWcagAaBodyText` / `kWcagAaLargeText` constants. Pure (only `dart:ui` `Color`).
- [x] TDD: 4 cases — black-on-white = 21.0, identical colors = 1.0, `#767676` on white at the WCAG body-text threshold (≥4.5 < 5.0), and symmetry.
- [x] `test/app/core/constants/app_colors_contrast_test.dart` — table-driven test on 6 documented pairs: charcoal-on-cream, charcoal-on-offWhite, charcoal-on-white, white-on-sageDark, white-on-terracotta, charcoal-on-terracottaLight.
- [x] **Violator surfaced + fixed**: white text on `sage` (#6B9080) = 3.54 — fails 4.5 AA threshold. Fix: switch primary button + theme + current-user chat bubble to `AppColors.sageDark` (#4A6B5A, ratio ≈5.4). `AppColors.sage` itself stays unchanged as a brand accent for non-text surfaces (icons, borders, status indicators where contrast doesn't apply). Comment in `app_theme.dart` + `primary_button.dart` documents the rationale.
- [x] `lib/app/core/constants/app_typography.dart` — `bodyLarge` / `bodyMedium` / `bodySmall` gain `height: 1.4` + `letterSpacing: 0.15` for comfortable reading at Material's default body sizes. Display + headline sizes left untouched so visual rhythm doesn't shift.
- [x] `lib/app/core/theme/app_theme.dart` — input-field `focusedBorder` switched from sage to sageDark to keep focus indicators visible against the verification banner's terracottaLight bg. ElevatedButton background updated to sageDark in both light + dark themes.
- [x] `test/app/core/widgets/primary_button_test.dart` — existing background-color assertion updated from `AppColors.sage` to `AppColors.sageDark` with an inline note explaining the AA driver.
- [x] TDD: full contrast test green after fixes (6 pairs all clear).
- [x] Verify: `flutter analyze` clean; `flutter test` 193 pass + 4 screenshot suites skipped

### Phase 3: `context.strings` extension — i18n-ready foundation (auth feature)

- **Goal**: every user-facing string in the auth feature reads through `context.strings.auth.*` (or `.errors.*`). Call-site shape matches what `flutter_localizations` will require later, so the eventual ARB migration is a one-file swap of the extension's body — zero UI files touched. Other features tracked in `todo.md` for follow-up extraction; this phase establishes the pattern.
- [x] `lib/app/core/i18n/app_strings.dart` — `AppStrings` is a regular **interface-shaped class** (not static). Sub-objects per feature: `AuthStrings`, `ErrorStrings`. Each field is an instance `String get …` — placeholders for future locale-aware impls. Single hand-written `_EnglishStrings extends AppStrings` impl in the same file (shape mirrors what an ARB-generated class will look like — flat-ish per feature so future ARB keys map 1:1, e.g. `authSignIn`, `authContinueWithGoogle`, `errorsPopupBlocked`).
- [x] `lib/app/core/i18n/app_strings.dart` — `extension StringsX on BuildContext { AppStrings get strings => AppStrings.fallbackEnglish; }`. Body returns the singleton today; future-ARB migration changes ONLY this getter to `AppStrings get strings => _AppLocalizationsAdapter(AppLocalizations.of(this)!)` — call sites stay identical.
- [x] `lib/app/core/i18n/app_strings.dart` — public-API doc comment naming the migration path explicitly: today's `_EnglishStrings()` ↔ tomorrow's `_AppLocalizationsAdapter(AppLocalizations.of(this)!)`. Adapter is one wrapper class that maps `_l.authSignIn` → `_l.authSignIn` etc. (mechanical because the field names match the eventual ARB keys).
- [x] Migrate auth-feature strings to `context.strings.auth.*`:
  - `lib/app/features/auth/presentation/auth_gate_screen.dart` — `context.strings.auth.heroTitle` ("CrewPoint"), `auth.tagline` ("Collaborate. Organize. Deliver."), `auth.dividerLabel` ("or continue with email").
  - `lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — `auth.continueWithGoogle`, `auth.continueWithApple`.
  - `lib/app/features/auth/presentation/widgets/email_auth_form.dart` — `auth.emailHint`, `auth.passwordHint`, `auth.fullNameHint`; `auth.signIn` / `auth.createAccount`; `auth.toggleToSignIn` / `auth.toggleToSignUp`; validator messages (`auth.validatorEmailRequired`, `auth.validatorEmailInvalid`, `auth.validatorPasswordTooShort`, `auth.validatorNameRequired`); suggest-provider snackbar (`auth.suggestProvider(providerLabel)` — accepts a positional arg so the same string template covers Apple / Google / "your existing provider").
  - `lib/app/features/auth/presentation/widgets/email_unverified_banner.dart` — `auth.verifyBannerTitle`, `auth.verifyBannerBody(email)` (templated), `auth.verifyBannerResend`, `auth.verifyBannerRefresh`.
- [x] `lib/app/features/auth/data/firebase_auth_error_messages.dart` — `firebaseAuthErrorMessage(String code)` now reads literals from `AppStrings.fallbackEnglish.errors.*` directly (no DI plumbing — the function is a pure top-level lookup). Inline doc explains: service-layer fallback uses the static English copy; UI code with a `BuildContext` should prefer `context.strings.errors.<key>` so the active locale wins once ARB is wired.
- [x] Existing widget/notifier tests (`firebase_auth_error_messages_test.dart`, `social_auth_buttons_test.dart`, `email_auth_form_suggest_provider_test.dart`) — string-presence assertions now read from `AppStrings.fallbackEnglish.auth.*` and `AppStrings.fallbackEnglish.errors.*`. `email_unverified_banner_test.dart` asserts only on `byKey` and the dynamic email substring; no literal-copy assertions to migrate.
- [x] TDD: `test/app/core/i18n/app_strings_test.dart` asserts `AppStrings.fallbackEnglish.auth.suggestProvider('Apple')` interpolates the label twice ("registered with Apple" + 'Continue with Apple'). Catches future regressions where the template format moves between languages.
- [x] TDD: `test/app/core/i18n/extension_test.dart` pumps a minimal `MaterialApp` and reads `context.strings.auth.signIn`, asserting it equals `AppStrings.fallbackEnglish.auth.signIn`. Locks in the extension contract.
- [x] `ai_specs/todo.md` — appended three entries under "Auth polish followups": migrate remaining features, wire `flutter_localizations` + ARB pipeline, add `MaterialApp.locale` switcher in Profile.
- [x] Verify: `flutter analyze` clean; `flutter test` 195 pass + 4 screenshot suites skipped

## Risks / Out of scope

- **Risks**:
  - Adjusting `AppColors` values affects every screen in the app, not just auth. Phase 2's contrast tests catch documented pairs only — visual regressions on Budget / Tasks / Chat surfaces need a manual eyeball pass before shipping prod.
  - Web favicon caches aggressively; users may need a hard refresh to see the new icon. Document in the manual smoke step.
  - `context.strings` migration in Phase 3 is wide-touch on the auth feature; tests are the safety net but a stray missed string compiles fine and only surfaces when ARB is wired. Watch the diff carefully.
  - Service-layer error messages (`firebase_auth_error_messages.dart`) can't take a `BuildContext` — they fall back to a static `AppStrings.fallbackEnglish`. When ARB is later wired, those messages will need a separate path (either a context-aware overload at the UI layer, or accept the fallback always being English in service code). Documented inline in the file but worth re-checking at ARB time.
- **Out of scope**:
  - Translating any strings to Spanish / Hindi / French — Phase 3 only sets up the foundation; translation delivery is separate work.
  - Migrating non-auth features to `context.strings.<feature>.*` (tracked in `todo.md`).
  - Full `flutter_localizations` + ARB pipeline setup (tracked in `todo.md` as a follow-up to Phase 3 — the `context.strings` extension is designed so this step swaps one file's body, not every call site).
  - Dark-mode contrast audit beyond the existing pairs; CrewPoint is light-default and dark-mode usage is anecdotal in V1.
  - Visual regression testing infra (Phase 6 of web-admin-reporting already ships placeholder screenshots; Phase 2's manual eyeball is sufficient until product captures real ones).
  - Custom branded Firebase Auth verification email template (separate spec).
