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
}
