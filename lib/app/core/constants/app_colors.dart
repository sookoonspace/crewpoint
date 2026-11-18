import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/palette.dart';

/// The old colour names, kept only so unmigrated screens compile; each now
/// forwards to the Slate and sage palette (Spec #186 Req 15).
///
/// New code reads `context.cp.colors`, which also follows dark mode. These
/// constants are the light values (the old ones were the same in both
/// modes). The file is deleted when the last screen moves (#208).
@Deprecated('Use context.cp.colors (lib/app/core/design/).')
abstract final class AppColors {
  // Primary - was charcoal; now the text colours.
  static const Color charcoal = Color(CpPalette.lightText);
  static const Color charcoalLight = Color(CpPalette.lightTextMuted);
  static const Color charcoalDark = Color(CpPalette.darkBackground);

  // Accent - was sage; now the one accent.
  static const Color sage = Color(CpPalette.lightAccent);
  static const Color sageLight = Color(CpPalette.darkAccent);
  static const Color sageDark = Color(CpPalette.lightAccent);

  // Alert - was terracotta; now the overdue and error colour.
  static const Color terracotta = Color(CpPalette.lightOverdue);
  static const Color terracottaLight = Color(CpPalette.darkOverdue);
  static const Color terracottaDark = Color(CpPalette.lightOverdue);

  // Neutrals. The cream background is gone (Req 10).
  static const Color white = Color(CpPalette.lightSurface);
  static const Color cream = Color(CpPalette.lightBackground);
  static const Color offWhite = Color(CpPalette.lightBackground);
  static const Color lightGrey = Color(CpPalette.lightBorder);
  static const Color mediumGrey = Color(CpPalette.darkTextMuted);
  static const Color darkGrey = Color(CpPalette.lightTextMuted);

  // Dark surfaces.
  static const Color surfaceDark = Color(CpPalette.darkBackground);
  static const Color surfaceDarkElevated = Color(CpPalette.darkSurface);

  // Semantic.
  static const Color success = Color(CpPalette.lightDone);
  static const Color error = Color(CpPalette.lightOverdue);
  static const Color warning = Color(CpPalette.lightDue);
  static const Color info = Color(CpPalette.lightAccent);

  // Status foregrounds and backgrounds.
  static const Color statusTodoFg = Color(CpPalette.lightTextMuted);
  static const Color statusTodoBg = Color(CpPalette.lightFill);
  static const Color statusDoingFg = Color(CpPalette.lightDue);
  static const Color statusDoingBg = Color(CpPalette.lightDueSoft);
  static const Color statusDoneFg = Color(CpPalette.lightDone);
  static const Color statusDoneBg = Color(CpPalette.lightDoneSoft);
  static const Color statusUrgentFg = Color(CpPalette.lightOverdue);
  static const Color statusUrgentBg = Color(CpPalette.lightOverdueSoft);

  // Money.
  static const Color moneyOwedToYouFg = Color(CpPalette.lightDone);
  static const Color moneyYouOweFg = Color(CpPalette.lightOverdue);

  static const Color statusInfoBg = Color(CpPalette.lightAccentSoft);
}
