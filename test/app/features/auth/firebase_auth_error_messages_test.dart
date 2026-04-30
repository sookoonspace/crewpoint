import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/auth/data/firebase_auth_error_messages.dart';

void main() {
  // Source assertions from `AppStrings.fallbackEnglish.errors` so the
  // tests stay green when the messages get translated — only the
  // English locale tracks these literal strings now.
  final errors = AppStrings.fallbackEnglish.errors;

  test('returns the actionable copy for auth/popup-blocked', () {
    expect(
      firebaseAuthErrorMessage('popup-blocked'),
      equals(errors.popupBlocked),
    );
  });

  test('maps auth/cancelled-popup-request and auth/popup-closed-by-user '
      'to the cancelled message', () {
    expect(
      firebaseAuthErrorMessage('cancelled-popup-request'),
      equals(errors.popupCancelled),
    );
    expect(
      firebaseAuthErrorMessage('popup-closed-by-user'),
      equals(errors.popupCancelled),
    );
  });

  test('falls back to the generic copy for unknown codes', () {
    expect(
      firebaseAuthErrorMessage('something-novel'),
      equals(errors.genericFallback),
    );
  });

  test('maps too-many-requests to the rate-limit message', () {
    expect(
      firebaseAuthErrorMessage('too-many-requests'),
      equals(errors.tooManyRequests),
    );
  });
}
