/// `AppRadioGroup<T>` — vertical (or horizontal) list of radio options with
/// a label + optional helper line.
///
/// Used by Create / Edit task to expose Priority (None / Low / Medium / High)
/// without inventing a per-screen layout. Generic on `T` so enum and `int`
/// payloads both work cleanly.
library;

import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

class AppRadioOption<T> {
  const AppRadioOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelText,
    this.helperText,
    this.direction = Axis.vertical,
  });

  final T? value;
  final List<AppRadioOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String? labelText;
  final String? helperText;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = options.map((opt) {
      return InkWell(
        onTap: () => onChanged(opt.value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<T>(value: opt.value),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(opt.label, style: theme.textTheme.bodyMedium),
                if (opt.subtitle != null)
                  Text(
                    opt.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mediumGrey,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
          ],
        ),
      );
    }).toList();

    // RadioGroup<T> (Flutter 3.32+) owns groupValue + onChanged so each
    // descendant Radio<T> only declares its own value.
    final group = RadioGroup<T>(
      groupValue: value,
      onChanged: onChanged,
      child: direction == Axis.vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tiles,
            )
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: tiles,
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null)
          Text(
            labelText!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.charcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (helperText != null && helperText!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mediumGrey,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        group,
      ],
    );
  }
}
