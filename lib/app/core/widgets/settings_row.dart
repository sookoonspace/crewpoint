import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';

/// Settings row used inside a `_SectionCard` on Profile (and elsewhere as
/// the standard "icon + title + optional subtitle + chevron + tap" row).
/// Promoted from the private `_SettingsTile` in profile_screen.dart.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: Icon(icon, color: AppColors.charcoal),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(color: AppColors.charcoal),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              key: const Key('settings.row.subtitle'),
              style: textTheme.bodySmall?.copyWith(color: AppColors.darkGrey),
            ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
      onTap: onTap,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
    );
  }
}
