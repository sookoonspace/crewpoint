import 'package:flutter/widgets.dart';

/// User-facing string surface for CrewPoint.
///
/// Today: a single hand-written English impl (`_EnglishStrings`).
/// Tomorrow (when `flutter_localizations` + ARB are wired): swap the
/// body of `StringsX.strings` to return an adapter over the generated
/// `AppLocalizations` class — every call site stays identical.
///
/// Migration path:
/// ```dart
/// // today
/// extension StringsX on BuildContext {
///   AppStrings get strings => const _EnglishStrings();
/// }
///
/// // tomorrow (one file's body changes; UI files do not)
/// extension StringsX on BuildContext {
///   AppStrings get strings =>
///       _AppLocalizationsAdapter(AppLocalizations.of(this)!);
/// }
/// ```
///
/// ARB-key naming convention: field names on the sub-objects map 1:1
/// to flat ARB keys via the future adapter (`auth.signIn` →
/// `_l.authSignIn`, `errors.popupBlocked` → `_l.errorsPopupBlocked`).
abstract class AppStrings {
  const AppStrings();

  AuthStrings get auth;
  ErrorStrings get errors;
  TasksStrings get tasks;

  /// Static English fallback. Used by service-layer code that has no
  /// `BuildContext` in scope (e.g. `firebaseAuthErrorMessage`). UI code
  /// should always prefer `context.strings.<feature>.<key>` because
  /// that path will pick up the active locale once ARB is wired.
  static const AppStrings fallbackEnglish = _EnglishStrings();
}

abstract class AuthStrings {
  const AuthStrings();

  // Hero / layout
  String get heroTitle;
  String get tagline;
  String get dividerLabel;

  // Social auth
  String get continueWithGoogle;
  String get continueWithApple;

  // Email form
  String get emailHint;
  String get passwordHint;
  String get fullNameHint;
  String get signIn;
  String get createAccount;
  String get toggleToSignIn;
  String get toggleToSignUp;

  // Validators
  String get validatorEmailRequired;
  String get validatorEmailInvalid;
  String get validatorPasswordTooShort;
  String get validatorNameRequired;

  // Suggest-provider snackbar (templated)
  String suggestProvider(String providerLabel);

  // Email-verification banner
  String get verifyBannerTitle;
  String verifyBannerBody(String email);
  String get verifyBannerResend;
  String get verifyBannerRefresh;

  // Auth-gate legal footer
  String get legalFooterPrefix; // e.g. "By continuing, you agree to our "
  String get legalFooterTermsLink; // e.g. "Terms"
  String get legalFooterAnd; // e.g. " and "
  String get legalFooterPrivacyLink; // e.g. "Privacy Policy"
  String get legalFooterSuffix; // e.g. "."
}

/// User-facing strings for the Tasks feature.
///
/// Phase 1 seeds the class with the labels the form-kit foundation needs;
/// later phases extend it with filter chip labels, sort/group menu labels,
/// priority pill labels, empty-state copy, and the `(copy)` suffix. All new
/// task-screen literals MUST land here rather than being hardcoded in
/// widgets — see `ai_specs/tasks-ux-overhaul-spec.md` `<boundaries>` i18n
/// contract.
abstract class TasksStrings {
  const TasksStrings();

  // Form section headers (used by Create / Edit task screens).
  String get sectionDetails;
  String get sectionAssignment;
  String get sectionTimingAndBudget;
}

abstract class ErrorStrings {
  const ErrorStrings();

  String get invalidEmail;
  String get wrongPassword;
  String get userNotFound;
  String get emailAlreadyInUse;
  String get weakPassword;
  String get networkRequestFailed;
  String get popupBlocked;
  String get popupCancelled;
  String get tooManyRequests;
  String get genericFallback;
}

/// Read translated strings from the current locale via `BuildContext`.
///
/// Today returns the English fallback singleton. The future ARB
/// migration replaces ONLY this getter's body — call sites stay
/// identical.
extension StringsX on BuildContext {
  AppStrings get strings => AppStrings.fallbackEnglish;
}

class _EnglishStrings extends AppStrings {
  const _EnglishStrings();

  @override
  AuthStrings get auth => const _EnglishAuthStrings();

  @override
  ErrorStrings get errors => const _EnglishErrorStrings();

  @override
  TasksStrings get tasks => const _EnglishTasksStrings();
}

class _EnglishTasksStrings extends TasksStrings {
  const _EnglishTasksStrings();

  @override
  String get sectionDetails => 'Details';

  @override
  String get sectionAssignment => 'Assignment';

  @override
  String get sectionTimingAndBudget => 'Timing & Budget';
}

class _EnglishAuthStrings extends AuthStrings {
  const _EnglishAuthStrings();

  @override
  String get heroTitle => 'CrewPoint';

  @override
  String get tagline => 'Collaborate. Organize. Deliver.';

  @override
  String get dividerLabel => 'or continue with email';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get fullNameHint => 'Full Name';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get toggleToSignIn => 'Already have an account? Sign In';

  @override
  String get toggleToSignUp => "Don't have an account? Sign Up";

  @override
  String get validatorEmailRequired => 'Please enter your email';

  @override
  String get validatorEmailInvalid => 'Please enter a valid email';

  @override
  String get validatorPasswordTooShort =>
      'Password must be at least 6 characters';

  @override
  String get validatorNameRequired => 'Please enter your name';

  @override
  String suggestProvider(String providerLabel) =>
      'This email is registered with $providerLabel. '
      'Tap "Continue with $providerLabel" above.';

  @override
  String get verifyBannerTitle =>
      'Verify your email so this sign-in stays active';

  @override
  String verifyBannerBody(String email) => 'We sent a link to $email.';

  @override
  String get verifyBannerResend => 'Resend';

  @override
  String get verifyBannerRefresh => "I've verified";

  @override
  String get legalFooterPrefix => 'By continuing, you agree to our ';

  @override
  String get legalFooterTermsLink => 'Terms';

  @override
  String get legalFooterAnd => ' and ';

  @override
  String get legalFooterPrivacyLink => 'Privacy Policy';

  @override
  String get legalFooterSuffix => '.';
}

class _EnglishErrorStrings extends ErrorStrings {
  const _EnglishErrorStrings();

  @override
  String get invalidEmail => 'The email address is invalid.';

  @override
  String get wrongPassword => 'Incorrect email or password.';

  @override
  String get userNotFound => 'No account found with this email.';

  @override
  String get emailAlreadyInUse => 'An account already exists with this email.';

  @override
  String get weakPassword => 'Password must be at least 6 characters.';

  @override
  String get networkRequestFailed =>
      'Network error. Please check your connection.';

  @override
  String get popupBlocked =>
      'Pop-ups are blocked - please allow pop-ups for this site and try again.';

  @override
  String get popupCancelled => 'Sign-in cancelled.';

  @override
  String get tooManyRequests =>
      'Too many attempts. Please wait a minute before trying again.';

  @override
  String get genericFallback =>
      'An unexpected error occurred. Please try again.';
}
