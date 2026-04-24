import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';

/// Lottie-based loading animation.
/// Falls back to CircularProgressIndicator if Lottie fails to load.
class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key, this.size = 48.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/animations/loading.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.sage,
        ),
      ),
    );
  }
}
