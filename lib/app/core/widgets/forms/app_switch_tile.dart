/// `AppSwitchTile` — list-tile-shaped boolean control with a switch.
///
/// Thin wrapper around `SwitchListTile` that gives every boolean control
/// a consistent shape across CrewPoint forms: title row, optional subtitle,
/// sage active colour, and rounded card-like outline matching the rest of
/// the forms kit.
///
/// Supersedes ad-hoc `SwitchListTile` usages in `event_dashboard_screen.dart`
/// (archive toggle) and `edit_event_screen.dart` (archive toggle). Migrate
/// opportunistically.
library;

import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';

class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
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
    return SwitchListTile(
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
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppColors.sage,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
    );
  }
}
