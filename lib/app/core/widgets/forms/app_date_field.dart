/// `AppDateField` — responsive date input.
///
/// Renders one of two layouts based on the **allotted width** (NOT `kIsWeb`):
///
/// * `width < Breakpoints.compactMax` (compact): a tappable list-tile-shaped
///   row that opens `showDatePicker` modally. Same UX every CrewPoint mobile
///   form already uses.
/// * `width >= Breakpoints.compactMax` (medium/expanded): an inline
///   `CalendarDatePicker` sitting inside an `OutlineInputBorder`-styled
///   container. The user picks dates without a modal round-trip.
///
/// Using `LayoutBuilder` (not `kIsWeb`) ensures a desktop browser resized
/// to mobile widths still gets the modal — the responsive cutover follows
/// real space, not the platform tag.
///
/// Allows past dates by default (`firstDate: DateTime(2000)`) so callers
/// editing back-dated rows don't fight the picker.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';

class AppDateField extends StatelessWidget {
  AppDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText,
    this.hintText = 'Optional',
    DateTime? firstDate,
    DateTime? lastDate,
    this.clearable = true,
  }) : firstDate = firstDate ?? DateTime(2000),
       lastDate = lastDate ?? DateTime.now().add(const Duration(days: 365 * 2));

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? labelText;
  final String hintText;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool clearable;

  Future<void> _openModal(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useInline = constraints.maxWidth >= Breakpoints.compactMax;
        return useInline ? _inline(context) : _modalTrigger(context);
      },
    );
  }

  Widget _modalTrigger(BuildContext context) {
    final df = DateFormat.yMMMd();
    final label = value == null ? hintText : df.format(value!);
    return InkWell(
      key: const Key('forms.date.trigger'),
      onTap: () => _openModal(context),
      borderRadius: AppRadius.borderLg,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: const Icon(AppIcons.calendar),
          suffixIcon: clearable && value != null
              ? IconButton(
                  key: const Key('forms.date.clear'),
                  icon: const Icon(AppIcons.actionClear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : null,
          border: const OutlineInputBorder(borderRadius: AppRadius.borderLg),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value == null ? AppColors.mediumGrey : AppColors.charcoal,
          ),
        ),
      ),
    );
  }

  Widget _inline(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.calendar, color: AppColors.darkGrey),
              const SizedBox(width: AppSpacing.sm),
              if (labelText != null)
                Expanded(
                  child: Text(
                    labelText!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (clearable && value != null)
                IconButton(
                  key: const Key('forms.date.clear'),
                  icon: const Icon(AppIcons.actionClear, size: 18),
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CalendarDatePicker(
            initialDate: value ?? DateTime.now(),
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
