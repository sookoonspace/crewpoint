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
  // Secondary / muted text on light surfaces — onSurfaceVariant cascade.
  // charcoalLight on cream measures 3.93:1 — passes large-text AA (3.0)
  // but FAILS body-text AA (4.5). On cream surfaces, prefer the charcoal
  // body color and rely on type weight/size for the secondary-tone
  // hierarchy. charcoalLight stays AA-safe on offWhite + white.
  _Pair(
    label: 'charcoalLight text on cream (large-text / quiet caption only)',
    foreground: AppColors.charcoalLight,
    background: AppColors.cream,
    minRatio: kWcagAaLargeText,
  ),
  _Pair(
    label: 'charcoalLight text on offWhite (secondary on default scaffold)',
    foreground: AppColors.charcoalLight,
    background: AppColors.offWhite,
    minRatio: kWcagAaBodyText,
  ),
  _Pair(
    label: 'charcoalLight text on white (secondary on cards)',
    foreground: AppColors.charcoalLight,
    background: AppColors.white,
    minRatio: kWcagAaBodyText,
  ),
];

/// Pairs that MUST stay below WCAG AA. Treat these as regression locks:
/// if any of these passes, someone has either lightened the foreground or
/// darkened the background — re-audit the screens that depend on these
/// colors before bumping the threshold.
const _forbiddenPairs = <_Pair>[
  _Pair(
    label:
        'mediumGrey text on cream — never use; theme should cascade '
        'charcoal/charcoalLight instead',
    foreground: AppColors.mediumGrey,
    background: AppColors.cream,
    minRatio: kWcagAaBodyText,
  ),
  _Pair(
    label: 'mediumGrey text on offWhite — same as above',
    foreground: AppColors.mediumGrey,
    background: AppColors.offWhite,
    minRatio: kWcagAaBodyText,
  ),
  _Pair(
    label:
        'lightGrey text on cream — never use; lightGrey is reserved for '
        'borders/dividers/icons, not text on light surfaces',
    foreground: AppColors.lightGrey,
    background: AppColors.cream,
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

  group('AppColors forbidden pairs MUST stay below WCAG AA '
      '(regression locks)', () {
    for (final p in _forbiddenPairs) {
      test(p.label, () {
        final ratio = contrastRatio(p.foreground, p.background);
        expect(
          ratio,
          lessThan(p.minRatio),
          reason:
              '${p.label}: ratio ${ratio.toStringAsFixed(2)} unexpectedly '
              'passed AA. Re-audit the screens that rely on this pair being '
              'the "forbidden / use a darker color" signal.',
        );
      });
    }
  });
}
