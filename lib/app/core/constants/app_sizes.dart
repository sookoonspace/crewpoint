/// Centralized non-spacing dimension tokens for CrewPoint.
///
/// Spacing values live in `AppSpacing`; border radii live in `AppRadius`.
/// This file is for icon / avatar / emoji / row-indent / ring sizes that
/// appear in widget code as bare doubles today.
///
/// **Promotion rule**: a value lands here only when used in ≥ 2 distinct
/// call sites in `lib/`. Single-use literals stay inline (see
/// `EmptyStatePlaceholder`'s `iconHero = 64` for an explicit example).
/// One exception: the emoji scale is promoted as a coherent group even
/// though each value is single-caller today — keeping them together
/// makes future tiles reusing the chat-row emoji size obvious.
abstract final class AppSizes {
  // ===== Icon sizes (Material default = 24) =====
  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  // ===== Avatar radii =====
  // Each value confirmed via grep to have ≥ 2 call sites in lib/.
  static const double avatarSm = 16;
  static const double avatarMd = 18;
  static const double avatarLg = 20;
  static const double avatarXl = 42;

  // ===== Emoji display sizes =====
  // Promoted as a group; each is single-caller today but the scale is
  // intentional — a future tile reusing emojiChat's 28 should not have to
  // rediscover the magic number.
  static const double emojiTile = 32;
  static const double emojiChat = 28;
  static const double emojiStat = 22;

  // ===== Settings list =====
  static const double settingsRowIndent = 56;

  // ===== Progress ring (default size used by ProgressRing) =====
  static const double progressRingSize = 48;
}
