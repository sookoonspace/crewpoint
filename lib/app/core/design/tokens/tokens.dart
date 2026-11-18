import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_scales.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_type.dart';

/// Every theme-read token in one place: `context.cp.colors.accent`,
/// `context.cp.space.lg`, `context.cp.type.titleLarge`.
///
/// Built by `CpTheme`; a theme without the extensions (a test that pumps a
/// bare `MaterialApp`) falls back to the light tokens rather than throwing.
@immutable
class CpTokens {
  const CpTokens._(this._theme);

  final ThemeData _theme;

  CpColors get colors =>
      _theme.extension<CpColors>() ??
      (_theme.brightness == Brightness.dark ? CpColors.dark : CpColors.light);
  CpType get type => _theme.extension<CpType>() ?? CpType.standard;
  CpSpacing get space => _theme.extension<CpSpacing>() ?? const CpSpacing();
  CpRadii get radii => _theme.extension<CpRadii>() ?? const CpRadii();
  CpSizes get sizes => _theme.extension<CpSizes>() ?? const CpSizes();
  CpMotion get motion => _theme.extension<CpMotion>() ?? const CpMotion();
  CpShadows get shadows =>
      _theme.extension<CpShadows>() ??
      (_theme.brightness == Brightness.dark ? CpShadows.dark : CpShadows.light);
}

extension CpTokensContext on BuildContext {
  /// The design tokens of the nearest theme.
  CpTokens get cp => CpTokens._(Theme.of(this));
}

/// The theme extensions for one brightness, in the order `CpTheme` adds them.
List<ThemeExtension<dynamic>> cpExtensions(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return [
    if (dark) CpColors.dark else CpColors.light,
    CpType.standard,
    const CpSpacing(),
    const CpRadii(),
    const CpSizes(),
    const CpMotion(),
    if (dark) CpShadows.dark else CpShadows.light,
  ];
}
