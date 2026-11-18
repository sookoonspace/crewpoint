import 'package:crewpoint_app/app/core/design/tokens/scale.dart';

/// The old size names, kept only so unmigrated screens compile; each now
/// forwards to the design tokens (Spec #186 Req 15). New code reads
/// `context.cp.sizes`. Deleted when the last screen moves (#208).
@Deprecated('Use context.cp.sizes (lib/app/core/design/).')
abstract final class AppSizes {
  static const double iconXs = CpScale.icon14;
  static const double iconSm = CpScale.icon16;
  static const double iconMd = CpScale.icon20;
  static const double iconLg = CpScale.icon24;
  static const double iconXl = CpScale.icon32;
  static const double iconHero = CpScale.icon64;

  static const double avatarSm = CpScale.avatar16;
  static const double avatarMd = CpScale.avatar18;
  static const double avatarLg = CpScale.avatar20;
  static const double avatarXl = CpScale.avatar42;

  static const double emojiTile = CpScale.emoji32;
  static const double emojiChat = CpScale.emoji28;
  static const double emojiStat = CpScale.emoji22;

  static const double settingsRowIndent = CpScale.rowIndent;

  static const double progressRingSize = CpScale.ring48;
}
