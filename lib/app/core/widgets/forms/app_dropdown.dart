/// `AppDropdown<T>` — single-select dropdown built on
/// `DropdownButtonFormField<T>` for keyboard navigation + Form integration.
///
/// On `kIsWeb`, each row gets a small extra vertical padding so the larger
/// pointer/keyboard hit targets feel right on desktop browsers. The mobile
/// rendering is unchanged.
///
/// Supersedes the bare `DropdownButton<T>` + `InputDecorator` pattern used
/// by `AssigneePicker` and the `DropdownButtonFormField` open-coded in
/// `CreateEventScreen` / `EditProfileScreen`. Migrate opportunistically.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
  });

  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const webPadding = kIsWeb ? AppSpacing.xs : 0.0;
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sage, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + webPadding,
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: webPadding),
              child: Text(
                item.label,
                style: TextStyle(
                  color: item.enabled
                      ? AppColors.charcoal
                      : AppColors.mediumGrey,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
