import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/data/firebase_auth_error_messages.dart';

void main() {
  test('returns the actionable copy for auth/popup-blocked', () {
    expect(firebaseAuthErrorMessage('popup-blocked'), contains('pop-ups'));
  });

  test('maps auth/cancelled-popup-request and auth/popup-closed-by-user '
      'to a "cancelled" message', () {
    expect(
      firebaseAuthErrorMessage('cancelled-popup-request'),
      contains('cancel'),
    );
    expect(
      firebaseAuthErrorMessage('popup-closed-by-user'),
      contains('cancel'),
    );
  });

  test('falls back to the generic copy for unknown codes', () {
    expect(firebaseAuthErrorMessage('something-novel'), contains('unexpected'));
  });
}
