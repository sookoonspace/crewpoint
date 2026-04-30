import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/wcag.dart';

/// Documented foreground/background pairs that the app actually puts
/// in front of users. Each pair must clear WCAG AA at the listed
/// threshold:
///
///   - body text → 4.5
///   - large text / UI components (icons, buttons, banners) → 3.0
///
/// When you add a new color combination to a screen, ADD IT HERE so
/// regressions surface in CI rather than at QA time.
class _Pair {
  const _Pair({
    required this.label,
    required this.foreground,
    required this.background,
    required this.minRatio,
  });

  final String label;
  final Color foreground;
  final Color background;
  final double minRatio;
}

const _pairs = <_Pair>[
  // Body / heading text on light surfaces.
  _Pair(
    label: 'charcoal text on cream (auth gate, banner)',
    foreground: AppColors.charcoal,
    background: AppColors.cream,
    minRatio: kWcagAaBodyText,
  ),
  _Pair(
    label: 'charcoal text on offWhite (scaffold default)',
    foreground: AppColors.charcoal,
    background: AppColors.offWhite,
    minRatio: kWcagAaBodyText,
  ),
  _Pair(
    label: 'charcoal text on white (cards, sheets)',
    foreground: AppColors.charcoal,
    background: AppColors.white,
    minRatio: kWcagAaBodyText,
  ),
  // White-on-accent CTAs.
  // NB: sage (#6B9080) only hits 3.5:1 with white text, which fails
  // WCAG AA for body-sized labels. Primary buttons + currentUser chat
  // bubbles render against sageDark (#4A6B5A) instead. sage stays as
  // a brand accent for icons / borders / status indicators where text
  // contrast doesn't apply.
  _Pair(
    label: 'white text on sageDark (primary button + current-user chat bubble)',
    foreground: AppColors.white,
    background: AppColors.sageDark,
    minRatio: kWcagAaBodyText,
  ),
  _Pair(
    label: 'white text on terracotta (destructive snackbar)',
    foreground: AppColors.white,
    background: AppColors.terracotta,
    minRatio: kWcagAaLargeText,
  ),
  // Unverified-email banner: terracottaLight bg + charcoal fg.
  _Pair(
    label: 'charcoal text on terracottaLight (verify-email banner)',
    foreground: AppColors.charcoal,
    background: AppColors.terracottaLight,
    minRatio: kWcagAaBodyText,
  ),
];

void main() {
  group('AppColors documented pairs meet WCAG AA', () {
    for (final p in _pairs) {
      test(p.label, () {
        final ratio = contrastRatio(p.foreground, p.background);
        expect(
          ratio,
          greaterThanOrEqualTo(p.minRatio),
          reason:
              '${p.label}: ratio ${ratio.toStringAsFixed(2)} '
              'must be >= ${p.minRatio} (WCAG AA).',
        );
      });
    }
  });
}
