import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';

/// Smoke check: every `AppAssets.X` resolves to the expected path string.
/// Doesn't load the file at runtime — that's a manual smoke step. This test
/// catches typos in the token file (e.g., dropping a `.json` extension or
/// a directory rename) before they ship.
void main() {
  group('Lottie animations', () {
    test('lottieError', () {
      expect(AppAssets.lottieError, 'assets/animations/error.json');
    });
    test('lottieEmptyState', () {
      expect(AppAssets.lottieEmptyState, 'assets/animations/empty_state.json');
    });
    test('lottieLoading', () {
      expect(AppAssets.lottieLoading, 'assets/animations/loading.json');
    });
    test('lottieSignOut', () {
      expect(AppAssets.lottieSignOut, 'assets/animations/sign_out.json');
    });
    test('lottieSuccess', () {
      expect(AppAssets.lottieSuccess, 'assets/animations/success.json');
    });
    test('lottieProfile', () {
      expect(AppAssets.lottieProfile, 'assets/animations/profile.json');
    });
  });

  group('Legal copy', () {
    test('legalPrivacyPolicy', () {
      expect(AppAssets.legalPrivacyPolicy, 'assets/legal/privacy-policy.md');
    });
    test('legalTermsOfService', () {
      expect(AppAssets.legalTermsOfService, 'assets/legal/terms-of-service.md');
    });
  });
}
