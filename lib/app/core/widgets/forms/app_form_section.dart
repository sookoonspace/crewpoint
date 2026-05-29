/// `AppFormSection` — visual grouping for a labelled cluster of form fields.
///
/// Renders the section title (`labelLarge` charcoal), an optional helper line
/// (`bodySmall` mediumGrey), and the supplied child column. Used to give the
/// Create / Edit task forms three distinct sections (Details / Assignment /
/// Timing & Budget) and is reusable anywhere a labelled form cluster is
/// useful (Edit Event, Edit Profile, future Settings screens).
///
/// Supersedes: ad-hoc `Text('Header') + Column([...])` patterns in
/// `create_event_screen.dart`, `edit_profile_screen.dart`, etc. New
/// screens should prefer this widget; legacy screens can migrate when
/// they're next touched.
library;

import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    required this.title,
    required this.child,
    this.helperText,
    this.padding,
  });

  final String title;
  final String? helperText;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helperText != null && helperText!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              helperText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
