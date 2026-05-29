import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';

/// Settings row used inside a `_SectionCard` on Profile (and elsewhere as
/// the standard "icon + title + optional subtitle + chevron + tap" row).
///
/// All colors resolve from `Theme.of(context).colorScheme` so the row
/// works in both light and dark themes.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Custom trailing widget (e.g. a value chip). When null, renders the
  /// default `chevronRight`.
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.onSurface),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              key: const Key('settings.row.subtitle'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
      trailing:
          trailing ??
          Icon(AppIcons.chevronRight, color: colors.onSurfaceVariant),
      onTap: onTap,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
    );
  }
}
