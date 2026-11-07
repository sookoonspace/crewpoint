import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Shown in place of a screen the viewer has no permission for. Rules refuse
/// the data anyway; this explains why there is nothing to see.
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.roles;
    return _Message(
      key: const Key('roles.noAccess'),
      icon: AppIcons.lock,
      title: strings.noAccessTitle,
      body: strings.noAccessBody,
    );
  }
}

/// Shown when data could not be read, with a retry.
class LoadFailedView extends StatelessWidget {
  const LoadFailedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.roles;
    return _Message(
      key: const Key('roles.loadFailed'),
      icon: AppIcons.wifiOff,
      title: strings.loadFailed,
      action: TextButton.icon(
        key: const Key('roles.retry'),
        onPressed: onRetry,
        icon: const Icon(AppIcons.actionRetry),
        label: Text(strings.retry),
      ),
    );
  }
}

/// A short centred message, such as a role or member that no longer exists.
class GoneView extends StatelessWidget {
  const GoneView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _Message(
    key: const Key('roles.gone'),
    icon: AppIcons.statusError,
    title: message,
  );
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: .min,
          spacing: AppSpacing.md,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null)
              Text(
                body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// Asks before leaving a form with unsaved changes. True means leave.
Future<bool> confirmDiscard(BuildContext context) async {
  final strings = context.strings.roles;
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(strings.discardTitle),
      content: Text(strings.discardBody),
      actions: [
        TextButton(
          key: const Key('roles.discard.keep'),
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(strings.keepEditing),
        ),
        TextButton(
          key: const Key('roles.discard.confirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(strings.discard),
        ),
      ],
    ),
  );
  return leave ?? false;
}

/// Asks to confirm a destructive step. True means go ahead.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required Key confirmKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(context.strings.roles.cancel),
        ),
        TextButton(
          key: confirmKey,
          onPressed: () => Navigator.of(dialog).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialog).colorScheme.error,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
