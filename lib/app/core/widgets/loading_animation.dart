import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';

/// Loading widget. Will use Lottie animation once assets are provided.
/// Falls back to a CircularProgressIndicator for now.
class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key, this.size = 48.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 3,
        color: AppColors.sage,
      ),
    );
  }
}
