/// `AppCheckboxTile` — list-tile-shaped boolean control with a checkbox.
///
/// Sibling to `AppSwitchTile` for cases where checkbox semantics fit better
/// (e.g., "Donate this cost" toggles in the Budget feature). Sage check
/// fill, rounded outline, consistent padding.
library;

import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';

class AppCheckboxTile extends StatelessWidget {
  const AppCheckboxTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      value: value,
      onChanged: enabled ? (v) => onChanged(v ?? false) : null,
      activeColor: AppColors.sage,
      controlAffinity: ListTileControlAffinity.leading,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
    );
  }
}
