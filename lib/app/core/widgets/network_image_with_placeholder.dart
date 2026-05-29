import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';

/// Displays a network image with loading shimmer and error fallback.
/// Use [isCircular] for avatars.
class NetworkImageWithPlaceholder extends StatelessWidget {
  const NetworkImageWithPlaceholder({
    super.key,
    required this.imageUrl,
    this.width = 104,
    this.height = 104,
    this.isCircular = false,
    this.placeholderIcon = AppIcons.image,
    this.lottieAsset,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final bool isCircular;
  final IconData placeholderIcon;
  final String? lottieAsset;
  final BoxFit fit;

  /// Convenience constructor for circular avatars.
  const NetworkImageWithPlaceholder.avatar({
    super.key,
    required this.imageUrl,
    this.width = 104,
    this.height = 104,
    this.fit = BoxFit.cover,
  }) : isCircular = true,
       placeholderIcon = AppIcons.navProfileFilled,
       lottieAsset = AppAssets.lottieProfile;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (imageUrl == null || imageUrl!.isEmpty) {
      content = _buildPlaceholder();
    } else {
      content = Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading();
        },
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    if (isCircular) {
      return ClipOval(
        child: SizedBox(width: width, height: height, child: content),
      );
    }

    return SizedBox(width: width, height: height, child: content);
  }

  Widget _buildLoading() {
    return Container(
      width: width,
      height: height,
      color: AppColors.lightGrey.withValues(alpha: 0.3),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.sage,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (lottieAsset != null) {
      return Container(
        width: width,
        height: height,
        color: AppColors.charcoalDark,
        child: Center(
          child: Lottie.asset(
            lottieAsset!,
            width: width * 0.6,
            height: height * 0.6,
            errorBuilder: (_, _, _) => Icon(
              placeholderIcon,
              size: width * 0.4,
              color: AppColors.sageLight,
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      color: AppColors.lightGrey.withValues(alpha: 0.3),
      child: Icon(
        placeholderIcon,
        size: width * 0.4,
        color: AppColors.mediumGrey,
      ),
    );
  }
}
