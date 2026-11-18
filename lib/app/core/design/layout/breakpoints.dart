import 'package:flutter/widgets.dart';

/// Material 3 width breakpoints + canonical screen-level outer padding.
///
/// Width-class boundaries follow the Material 3 layout adaptation guide:
/// `width < 600` Compact · `600 ≤ width < 840` Medium ·
/// `840 ≤ width < 1200` Expanded · `1200 ≤ width < 1600` Large ·
/// `width ≥ 1600` Extra-large.
abstract final class Breakpoints {
  static const double compactMax = 600.0;
  static const double mediumMax = 840.0;
  static const double expandedMax = 1200.0;
  static const double largeMax = 1600.0;

  /// Canonical screen-level outer horizontal padding. Returns 24 px at
  /// compact/medium viewports and 40 px at expanded+. Use this on every
  /// routed page being wrapped in [ContentMaxWidth] regardless of which
  /// existing AppSpacing token the page used before.
  static double screenHorizontalPadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumMax ? 40.0 : 24.0;
}
