import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

void main() {
  test('auth.suggestProvider interpolates the provider label twice', () {
    final msg = AppStrings.fallbackEnglish.auth.suggestProvider('Apple');
    expect(msg, contains('registered with Apple'));
    expect(msg, contains('Continue with Apple'));
  });
}
