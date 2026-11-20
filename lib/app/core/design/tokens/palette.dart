/// The raw colour values of CrewPoint's look: Slate and sage (Spec #186,
/// ledger L22), copied from the approved mockups in
/// `docs/design/mockups/round-1/event-home-slate-sage-lucide-{light,dark}.html`.
///
/// This is the one place a colour changes. Values are ARGB integers so the
/// same file feeds the Flutter theme ([CpColors]) and the PDF theme
/// ([CpPdfTheme]) without importing Flutter. Screens never read this file:
/// they read [CpColors] through the theme.
abstract final class CpPalette {
  // ===== Light =====
  static const int lightBackground = 0xFFF6F7F8;
  static const int lightSurface = 0xFFFFFFFF;
  static const int lightFill = 0xFFEEF1F3;
  static const int lightBorder = 0xFFE2E6EA;
  static const int lightText = 0xFF1E2A33;
  static const int lightTextMuted = 0xFF5A6672;
  static const int lightAccent = 0xFF4A7A5C;
  static const int lightAccentSoft = 0xFFE5EFE8;
  static const int lightOnAccent = 0xFFFFFFFF;
  static const int lightBanner = 0xFF4A7A5C;
  static const int lightOnBanner = 0xFFFFFFFF;
  static const int lightDone =
      0xFF2B774B; // mockup #2E7D4F, darkened for AA on doneSoft
  static const int lightDoneSoft = 0xFFE6F2EA;
  static const int lightDue = 0xFF9A6200;
  static const int lightDueSoft = 0xFFFBF0DC;
  static const int lightOverdue = 0xFFB3261E;
  static const int lightOverdueSoft = 0xFFFBE6E4;

  // ===== Dark =====
  static const int darkBackground = 0xFF111518;
  static const int darkSurface = 0xFF1A2026;
  static const int darkFill = 0xFF222930;
  static const int darkBorder = 0xFF29323A;
  static const int darkText = 0xFFE7EBEE;
  static const int darkTextMuted = 0xFF9AA5AF;
  static const int darkAccent = 0xFF82AE90;
  static const int darkAccentSoft = 0xFF1F2F25;
  static const int darkOnAccent = 0xFF0D1A12;
  static const int darkBanner = 0xFF2C4636;
  static const int darkOnBanner = 0xFFDCEADF;
  static const int darkDone = 0xFF73C796;
  static const int darkDoneSoft = 0xFF1B2E23;
  static const int darkDue = 0xFFE7B04A;
  static const int darkDueSoft = 0xFF33280F;
  static const int darkOverdue = 0xFFF2877F;
  static const int darkOverdueSoft = 0xFF3A1B19;

  // ===== Shadows =====
  /// Ink (16, 24, 40) at 4%: the faint card shadow in light mode.
  static const int lightShadowCard = 0x0A101828;

  /// Ink at 16%: menus and sheets in light mode.
  static const int lightShadowRaised = 0x29101828;

  /// Black at 50%: menus and sheets in dark mode. Dark cards have no shadow.
  static const int darkShadowRaised = 0x80000000;

  // ===== Fixed in both themes =====
  /// A QR code needs dark modules on a light ground to scan, in either theme.
  static const int qrInk = 0xFF000000;
  static const int qrPaper = 0xFFFFFFFF;
}
