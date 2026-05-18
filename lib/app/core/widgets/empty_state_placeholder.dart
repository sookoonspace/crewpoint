import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Branded "nothing here" surface. Lottie animation + title + optional
/// subtitle + optional CTA. Falls back to an icon when the lottie asset
/// fails to load. Pure presentation — no Riverpod, no I/O.
class EmptyStatePlaceholder extends StatelessWidget {
  const EmptyStatePlaceholder({
    super.key,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.ctaKey,
    this.lottieAsset = AppAssets.lottieEmptyState,
    this.iconFallback = AppIcons.inbox,
    this.lottieHeight = 160,
  });

  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final Key? ctaKey;
  final String? lottieAsset;
  final IconData iconFallback;
  final double lottieHeight;

  /// Dedupe `developer.log` calls so the same broken asset doesn't spam
  /// the console on every rebuild.
  static final Set<String> _loggedAssets = <String>{};

  Widget _buildFallbackIcon() {
    return Icon(
      iconFallback,
      key: const Key('emptyState.iconFallback'),
      size: 64,
      color: AppColors.lightGrey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    final cta = ctaLabel;
    final onCtaCb = onCta;
    final hasCta = cta != null && onCtaCb != null;
    final asset = lottieAsset;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: lottieHeight,
              child: asset == null
                  ? _buildFallbackIcon()
                  : Lottie.asset(
                      asset,
                      key: const Key('emptyState.lottie'),
                      height: lottieHeight,
                      repeat: true,
                      errorBuilder: (_, _, _) {
                        if (_loggedAssets.add(asset)) {
                          developer.log(
                            'Lottie asset failed: $asset',
                            name: 'empty-state',
                          );
                        }
                        return _buildFallbackIcon();
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              key: const Key('emptyState.title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.charcoal),
              textAlign: TextAlign.center,
            ),
            if (subtitleText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitleText,
                key: const Key('emptyState.subtitle'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (hasCta) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                key: ctaKey ?? const Key('emptyState.cta'),
                onPressed: onCtaCb,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sage,
                  side: const BorderSide(color: AppColors.sage),
                ),
                child: Text(cta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
