/// Centralized asset path tokens for CrewPoint.
///
/// Every hardcoded `assets/...` path the app loads at runtime lives here so
/// renaming or moving an asset is a single-line change. The launcher icon
/// path stays in `pubspec.yaml` (build-time only, no runtime references).
abstract final class AppAssets {
  // ===== Lottie animations =====
  static const String lottieError = 'assets/animations/error.json';
  static const String lottieEmptyState = 'assets/animations/empty_state.json';
  static const String lottieLoading = 'assets/animations/loading.json';
  static const String lottieSignOut = 'assets/animations/sign_out.json';
  static const String lottieSuccess = 'assets/animations/success.json';
  static const String lottieProfile = 'assets/animations/profile.json';

  // ===== Legal copy (rendered by MarkdownRenderScreen) =====
  static const String legalPrivacyPolicy = 'assets/legal/privacy-policy.md';
  static const String legalTermsOfService = 'assets/legal/terms-of-service.md';
}
