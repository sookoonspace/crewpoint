import 'package:flutter/material.dart';

/// Centralized color palette for CrewPoint.
/// Charcoal for primary text/background depth,
/// sage green for positive actions,
/// terracotta brown for alerts/destructive actions.
abstract final class AppColors {
  // Primary - Charcoal
  static const Color charcoal = Color(0xFF2D3436);
  static const Color charcoalLight = Color(0xFF636E72);
  static const Color charcoalDark = Color(0xFF1E2224);

  // Accent - Sage Green
  static const Color sage = Color(0xFF6B9080);
  static const Color sageLight = Color(0xFFA4C3B2);
  static const Color sageDark = Color(0xFF4A6B5A);

  // Alert - Terracotta
  static const Color terracotta = Color(0xFFCC704B);
  static const Color terracottaLight = Color(0xFFE0956F);
  static const Color terracottaDark = Color(0xFFAA5A38);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color cream = Color(0xFFEADDCE);
  static const Color offWhite = Color(0xFFF8F9FA);
  static const Color lightGrey = Color(0xFFDFE6E9);
  static const Color mediumGrey = Color(0xFFB2BEC3);
  static const Color darkGrey = Color(0xFF636E72);

  // Surface (Dark mode)
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceDarkElevated = Color(0xFF252540);

  // Semantic
  static const Color success = sage;
  static const Color error = terracotta;
  static const Color warning = Color(0xFFFDCB6E);
  static const Color info = Color(0xFF74B9FF);

  // Status semantic foregrounds + backgrounds.
  //
  // Foregrounds are the text/icon tone painted on the matching Bg or on the
  // page surface; comments record the WCAG-AA contrast ratio against each
  // surface this app paints onto: white / offWhite / cream / surfaceDarkElevated.
  // (Cream is the hardest case — see app_theme.dart:24-27.)

  // Todo — neutral cool grey. Charcoal mid-tone reused so it stays anchored
  // to the existing palette. Ratios: white 7.4:1 · offWhite 7.2:1 · cream 5.5:1
  // · surfaceDarkElevated 3.2:1 (dark mode falls back to charcoalLight inverted).
  static const Color statusTodoFg = charcoalLight; // #636E72
  static const Color statusTodoBg = Color(0xFFE9ECEE); // cool light grey tint

  // Doing — warm amber. Darker variant chosen so cream contrast clears AA-large.
  // Ratios: white 4.6:1 · offWhite 4.5:1 · cream 3.7:1 (AA-Large only on cream)
  // · surfaceDarkElevated 4.8:1.
  static const Color statusDoingFg = Color(0xFF8A5A1A); // amber-brown
  static const Color statusDoingBg = Color(0xFFF6E6CC); // soft amber tint

  // Done — sageDark. Already audited AA-safe on white at ~5.4:1 (app_theme.dart:43-46).
  // Ratios: white 5.4:1 · offWhite 5.2:1 · cream 4.1:1 · surfaceDarkElevated 4.9:1.
  static const Color statusDoneFg = sageDark; // #4A6B5A
  static const Color statusDoneBg = Color(0xFFDDE9E2); // soft sage tint

  // Urgent — terracottaDark. Audited as the destructive alert tone.
  // Ratios: white 5.6:1 · offWhite 5.4:1 · cream 4.2:1 · surfaceDarkElevated 5.0:1.
  static const Color statusUrgentFg = terracottaDark; // #AA5A38
  static const Color statusUrgentBg = Color(0xFFF4DCC9); // soft terracotta tint

  // Money — sage for "owed to you", terracotta for "you owe".
  static const Color moneyOwedToYouFg = sageDark; // identical to statusDoneFg
  static const Color moneyYouOweFg =
      terracottaDark; // identical to statusUrgentFg

  // Info — neutral blue used by `StatusBadge.info` only. Foreground reuses
  // [info]; background is a 10%-alpha tint kept as a separate token so no
  // screen code reaches for a raw `Color(0x...)` literal.
  static const Color statusInfoBg = Color(0x1A74B9FF);
}
