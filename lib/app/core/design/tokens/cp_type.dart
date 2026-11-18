import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/scale.dart';

/// Type tokens, read with `context.cp.type`.
///
/// Inter for all text and Inter Display for headings, both bundled in
/// `assets/fonts/` (Spec #186 Req 9, ledger L15). Styles carry no colour:
/// the theme applies [CpColors.text], and components pick muted or accent
/// colours themselves. The roles follow Material's text theme, so screens
/// that still read `Theme.of(context).textTheme` get the same styles.
@immutable
class CpType extends ThemeExtension<CpType> {
  const CpType({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.stat,
    required this.number,
  });

  /// Body text. Changing the font is this line and [displayFont].
  static const String textFont = 'Inter';

  /// Headings, stats and large numbers.
  static const String displayFont = 'InterDisplay';

  static const _tabular = [FontFeature.tabularFigures()];

  static const standard = CpType(
    displayLarge: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.4,
      fontSize: CpScale.type32,
    ),
    displayMedium: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.3,
      fontSize: CpScale.type28,
    ),
    displaySmall: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.3,
      fontSize: CpScale.type26,
    ),
    // The page title in the mockups.
    headlineLarge: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.3,
      fontSize: CpScale.type26,
    ),
    headlineMedium: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.2,
      fontSize: CpScale.type22,
    ),
    headlineSmall: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.2,
      fontSize: CpScale.type20,
    ),
    // Section headings and top bar titles.
    titleLarge: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.1,
      fontSize: CpScale.type17,
    ),
    // Row titles.
    titleMedium: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w500,
      height: 1.4,
      fontSize: CpScale.type16,
    ),
    titleSmall: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w500,
      height: 1.4,
      fontSize: CpScale.type15,
    ),
    bodyLarge: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w400,
      height: 1.4,
      fontSize: CpScale.type16,
    ),
    bodyMedium: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w400,
      height: 1.4,
      fontSize: CpScale.type15,
    ),
    // Row subtitles and help text.
    bodySmall: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w400,
      height: 1.4,
      fontSize: CpScale.type13,
    ),
    // Buttons.
    labelLarge: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w600,
      height: 1.3,
      fontSize: CpScale.type15,
    ),
    // Chips and field labels.
    labelMedium: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w600,
      height: 1.3,
      fontSize: CpScale.type13,
    ),
    labelSmall: TextStyle(
      fontFamily: textFont,
      fontWeight: FontWeight.w500,
      height: 1.3,
      fontSize: CpScale.type12,
    ),
    // Stat card values: digits keep their width as they change.
    stat: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w600,
      height: 1.2,
      fontSize: CpScale.type22,
      fontFeatures: _tabular,
    ),
    // Large money and balance figures.
    number: TextStyle(
      fontFamily: displayFont,
      fontWeight: FontWeight.w600,
      height: 1.2,
      fontSize: CpScale.type28,
      fontFeatures: _tabular,
    ),
  );

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  final TextStyle stat;
  final TextStyle number;

  /// The Material text theme built from these styles, in [color].
  TextTheme textTheme(Color color) => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  ).apply(bodyColor: color, displayColor: color);

  @override
  CpType copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
    TextStyle? stat,
    TextStyle? number,
  }) => CpType(
    displayLarge: displayLarge ?? this.displayLarge,
    displayMedium: displayMedium ?? this.displayMedium,
    displaySmall: displaySmall ?? this.displaySmall,
    headlineLarge: headlineLarge ?? this.headlineLarge,
    headlineMedium: headlineMedium ?? this.headlineMedium,
    headlineSmall: headlineSmall ?? this.headlineSmall,
    titleLarge: titleLarge ?? this.titleLarge,
    titleMedium: titleMedium ?? this.titleMedium,
    titleSmall: titleSmall ?? this.titleSmall,
    bodyLarge: bodyLarge ?? this.bodyLarge,
    bodyMedium: bodyMedium ?? this.bodyMedium,
    bodySmall: bodySmall ?? this.bodySmall,
    labelLarge: labelLarge ?? this.labelLarge,
    labelMedium: labelMedium ?? this.labelMedium,
    labelSmall: labelSmall ?? this.labelSmall,
    stat: stat ?? this.stat,
    number: number ?? this.number,
  );

  @override
  CpType lerp(covariant CpType? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return CpType(
      displayLarge: mix(displayLarge, other.displayLarge),
      displayMedium: mix(displayMedium, other.displayMedium),
      displaySmall: mix(displaySmall, other.displaySmall),
      headlineLarge: mix(headlineLarge, other.headlineLarge),
      headlineMedium: mix(headlineMedium, other.headlineMedium),
      headlineSmall: mix(headlineSmall, other.headlineSmall),
      titleLarge: mix(titleLarge, other.titleLarge),
      titleMedium: mix(titleMedium, other.titleMedium),
      titleSmall: mix(titleSmall, other.titleSmall),
      bodyLarge: mix(bodyLarge, other.bodyLarge),
      bodyMedium: mix(bodyMedium, other.bodyMedium),
      bodySmall: mix(bodySmall, other.bodySmall),
      labelLarge: mix(labelLarge, other.labelLarge),
      labelMedium: mix(labelMedium, other.labelMedium),
      labelSmall: mix(labelSmall, other.labelSmall),
      stat: mix(stat, other.stat),
      number: mix(number, other.number),
    );
  }
}
