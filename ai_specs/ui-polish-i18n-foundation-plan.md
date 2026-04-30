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
- [ ] `web/favicon.png` — replace with the CrewPoint launcher icon downsized to 32×32 (browsers also accept 16×16; the existing 16×16 is too small for high-DPI tabs). Source from `assets/icons/launcher_icon.png` via `dart run scripts/regenerate_favicon.dart` OR a one-time hand resize — pick whichever ships fastest.
- [ ] `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-{192,512}.png` — verify they already use the CrewPoint launcher icon (Phase 4 of web-admin-reporting reused them as-is). Regenerate if any are still default-Flutter.
- [ ] `web/index.html` — already correct; no change.
- [ ] `lib/app/features/auth/presentation/auth_gate_screen.dart` — wrap the body's `Column` in `Center > ConstrainedBox(maxWidth: 480)` so buttons + text fields stop at a readable column on web; mobile (narrow widths) is unaffected because `maxWidth` clamps at the viewport width on phones.
- [ ] TDD: `auth_gate_screen` widget test pumps at desktop width (1280 × 800) and asserts the inner `Column` has a constrained width ≤ 480 px (use `tester.getSize(finder)` on a stable selector).
- [ ] TDD: same test pumps at iPhone width (375 × 812) and asserts the column fills the viewport (no wasted side gutters on mobile).
- [ ] Manual smoke (web): `flutter build web --release --dart-define=FLAVOR=dev && firebase deploy --only hosting:crewpoint-dev`; open in Chrome at 1280 width — confirm tab shows the CrewPoint icon and the auth gate isn't stretched. **Manual user step**
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Color contrast + typography readability

- **Goal**: every foreground/background pair the app uses meets WCAG AA (4.5:1 body, 3:1 large/UI). Typography gets a polish pass — line height + weight tuning.
- [ ] `lib/app/core/constants/wcag.dart` — small pure helper: `double contrastRatio(Color fg, Color bg)` per WCAG 2.1 relative luminance. Pure function, no Flutter UI deps beyond `Color`.
- [ ] TDD: `wcag.dart` returns 21.0 for black-on-white; ≈4.5 for known borderline pair (e.g. `#767676` on white); symmetric (swapping fg/bg returns the same ratio).
- [ ] `test/app/core/constants/app_colors_contrast_test.dart` — table-driven test asserting WCAG AA on every documented pair this app uses today: `charcoal`-on-`cream`, `charcoal`-on-`offWhite`, `charcoal`-on-`white`, `white`-on-`sage`, `white`-on-`terracotta`, `charcoal`-on-`terracottaLight` (the unverified-email banner foreground/background), `mediumGrey`-on-`cream` (the auth-gate subtitle "Collaborate. Organize. Deliver.").
- [ ] Fix the violators surfaced by the contrast test. Most likely candidates from a quick scan: `mediumGrey` (#B2BEC3) on `cream` (#EADDCE) — body text on auth gate; `charcoalLight` on `cream` for hint/secondary copy. Adjust either the colors themselves (preferred — single source of truth) or swap the usage to a higher-contrast token.
- [ ] `lib/app/core/constants/app_typography.dart` — bump body text `letterSpacing: 0.15` and `height: 1.4` for `bodyLarge` / `bodyMedium`; verify visually that the result reads cleanly. Heading sizes already shipped; no change needed unless contrast forces a weight bump.
- [ ] `lib/app/core/theme/app_theme.dart` — verify `OutlinedButton` foreground color matches the higher-contrast token; the social-auth buttons currently inherit defaults that may render as a faint sage-on-cream.
- [ ] TDD: contrast test re-asserted green after fixes.
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: `context.strings` extension — i18n-ready foundation (auth feature)

- **Goal**: every user-facing string in the auth feature reads through `context.strings.auth.*` (or `.errors.*`). Call-site shape matches what `flutter_localizations` will require later, so the eventual ARB migration is a one-file swap of the extension's body — zero UI files touched. Other features tracked in `todo.md` for follow-up extraction; this phase establishes the pattern.
- [ ] `lib/app/core/i18n/app_strings.dart` — `AppStrings` is a regular **interface-shaped class** (not static). Sub-objects per feature: `AuthStrings`, `ErrorStrings`. Each field is an instance `String get …` — placeholders for future locale-aware impls. Single hand-written `_EnglishStrings extends AppStrings` impl in the same file (shape mirrors what an ARB-generated class will look like — flat-ish per feature so future ARB keys map 1:1, e.g. `authSignIn`, `authContinueWithGoogle`, `errorsPopupBlocked`).
- [ ] `lib/app/core/i18n/app_strings.dart` — `extension StringsX on BuildContext { AppStrings get strings => const _EnglishStrings(); }`. Body returns the singleton today; future-ARB migration changes ONLY this getter to `AppStrings get strings => _AppLocalizationsAdapter(AppLocalizations.of(this)!)` — call sites stay identical.
- [ ] `lib/app/core/i18n/app_strings.dart` — public-API doc comment naming the migration path explicitly: today's `_EnglishStrings()` ↔ tomorrow's `_AppLocalizationsAdapter(AppLocalizations.of(this)!)`. Adapter is one wrapper class that maps `_l.authSignIn` → `_l.authSignIn` etc. (mechanical because the field names match the eventual ARB keys).
- [ ] Migrate auth-feature strings to `context.strings.auth.*`:
  - `lib/app/features/auth/presentation/auth_gate_screen.dart` — `context.strings.auth.heroTitle` ("CrewPoint"), `auth.tagline` ("Collaborate. Organize. Deliver."), `auth.dividerLabel` ("or continue with email").
  - `lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — `auth.continueWithGoogle`, `auth.continueWithApple`.
  - `lib/app/features/auth/presentation/widgets/email_auth_form.dart` — `auth.emailHint`, `auth.passwordHint`, `auth.fullNameHint`; `auth.signIn` / `auth.createAccount`; `auth.toggleToSignIn` / `auth.toggleToSignUp`; validator messages (`auth.validatorEmailRequired`, `auth.validatorEmailInvalid`, `auth.validatorPasswordTooShort`, `auth.validatorNameRequired`); suggest-provider snackbar (`auth.suggestProvider(providerLabel)` — accepts a positional arg so the same string template covers Apple / Google / "your existing provider").
  - `lib/app/features/auth/presentation/widgets/email_unverified_banner.dart` — `auth.verifyBannerTitle`, `auth.verifyBannerBody(email)` (templated), `auth.verifyBannerResend`, `auth.verifyBannerRefresh`.
- [ ] `lib/app/features/auth/data/firebase_auth_error_messages.dart` — `firebaseAuthErrorMessage(String code)` cannot easily take a `BuildContext` (it's called from pure service layers). Two-track approach:
  - Keep the function pure-string-out, but route every literal through a top-level `_messages` map seeded by an `AppStrings` instance the function gets via dependency injection (or via a static accessor `AppStrings.fallbackEnglish` — used only when no `BuildContext` is in scope).
  - Document in the file that error-message lookups in service code use the fallback; UI code translating an error always calls `context.strings.errors.<key>` directly when it has access.
- [ ] Existing widget/notifier tests (`firebase_auth_error_messages_test.dart`, `social_auth_buttons_test.dart`, `email_unverified_banner_test.dart`, `email_auth_form_suggest_provider_test.dart`) — update string-presence assertions to read from `AppStrings.fallbackEnglish.*` (or whatever the test seam is named) so translations don't break tests later. Widget tests that use `find.text(...)` keep working because `MaterialApp` is in the tree → `context.strings` returns the same `_EnglishStrings()` body.
- [ ] TDD: a small unit test on `_EnglishStrings` asserts that `auth.suggestProvider('Apple')` interpolates correctly (`This email is registered with Apple. …`). Catches any future regression where the template format moves between languages.
- [ ] TDD: a small `extension_test.dart` pumps a minimal `MaterialApp` and reads `context.strings.auth.signIn`, asserting it equals `_EnglishStrings().auth.signIn`. Locks in the extension contract.
- [ ] `ai_specs/todo.md` — under "Auth polish followups" append:
  - "Migrate strings in remaining features (dashboard, events, tasks, budget, chat, profile) to `context.strings.<feature>.*`. ~226 of the 276 `Text(...)` call sites in `lib/` remain."
  - "Wire `flutter_localizations` + `gen-l10n` ARB pipeline. Add `lib/l10n/app_en.arb` mirroring the shape in `app_strings.dart`; later add `app_es.arb`, `app_hi.arb`, `app_fr.arb`. Migration is one-file: replace the body of `extension StringsX on BuildContext { ... }` with the `AppLocalizations` adapter. Zero UI call-site changes."
  - "Add a `MaterialApp.locale` switcher to Profile so QA can preview non-English locales without changing system settings."
- [ ] Verify: `flutter analyze` && `flutter test`

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
