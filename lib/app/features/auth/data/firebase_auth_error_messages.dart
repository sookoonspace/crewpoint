import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Maps a Firebase Auth error code (the part after `auth/`) to the
/// user-facing copy CrewPoint shows in snackbars / form errors.
///
/// Pulled out as a top-level pure function so the popup-error mappings
/// added for web Apple sign-in can be unit-tested without instantiating
/// `FirebaseAuthService` (which would otherwise need a real Firebase
/// binding).
///
/// Service-layer fallback: this function reads from
/// `AppStrings.fallbackEnglish.errors` because no `BuildContext` is in
/// scope here. UI code that has a context should prefer
/// `context.strings.errors.<key>` directly so the message picks up the
/// active locale once `flutter_localizations` is wired.
String firebaseAuthErrorMessage(String code) {
  final errors = AppStrings.fallbackEnglish.errors;
  return switch (code) {
    'invalid-email' => errors.invalidEmail,
    'wrong-password' || 'invalid-credential' => errors.wrongPassword,
    'user-not-found' => errors.userNotFound,
    'email-already-in-use' => errors.emailAlreadyInUse,
    'weak-password' => errors.weakPassword,
    'network-request-failed' => errors.networkRequestFailed,
    'popup-blocked' => errors.popupBlocked,
    'cancelled-popup-request' ||
    'popup-closed-by-user' => errors.popupCancelled,
    'too-many-requests' => errors.tooManyRequests,
    _ => errors.genericFallback,
  };
}
