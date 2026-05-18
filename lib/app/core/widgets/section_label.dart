import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';

/// Uppercase, letter-spaced section header used above grouped content
/// (e.g., "2 UPCOMING EVENTS", "BREAKDOWN", "SETTINGS").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.darkGrey,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
