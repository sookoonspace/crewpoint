import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_switch_tile.dart';
import 'package:crewpoint_app/app/features/profile/application/notification_prefs_provider.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';

/// `/profile/notifications` — surfaces the master push toggle + per-category
/// switches. Server-side enforcement of these flags lives in
/// `functions/src/events/onUrgentMessageCreated.ts`.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final s = context.strings.profile;

    return Scaffold(
      appBar: AppBar(title: Text(s.notifications), elevation: 0),
      body: uid == null
          ? const Center(child: Text('Sign in required'))
          : _Body(uid: uid),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrefs = ref.watch(notificationPrefsProvider(uid));
    return ContentMaxWidth(
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.lg,
        ),
        child: asyncPrefs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Could not load notification settings',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          data: (prefs) => _PrefsForm(uid: uid, prefs: prefs),
        ),
      ),
    );
  }
}

class _PrefsForm extends ConsumerWidget {
  const _PrefsForm({required this.uid, required this.prefs});

  final String uid;
  final NotificationPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationPrefsProvider(uid).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSwitchTile(
          key: const Key('notifSettings.pushEnabled.tile'),
          title: 'Push notifications',
          subtitle: prefs.pushEnabled
              ? 'Receive alerts on this device.'
              : 'All notifications are muted.',
          value: prefs.pushEnabled,
          onChanged: (v) =>
              _safeUpdate(context, () => controller.setPushEnabled(v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Categories',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSwitchTile(
          key: const Key('notifSettings.urgentChat.tile'),
          title: 'Urgent chat alerts',
          subtitle:
              'Critical messages in group chats. Enable to receive 🚨 alerts.',
          value: prefs.urgentChat,
          enabled: prefs.pushEnabled,
          onChanged: (v) =>
              _safeUpdate(context, () => controller.setUrgentChat(v)),
        ),
        AppSwitchTile(
          key: const Key('notifSettings.taskUpdates.tile'),
          title: 'Task assignments',
          subtitle: 'When someone assigns a task to you.',
          value: prefs.taskUpdates,
          enabled: prefs.pushEnabled,
          onChanged: (v) =>
              _safeUpdate(context, () => controller.setTaskUpdates(v)),
        ),
        AppSwitchTile(
          key: const Key('notifSettings.payments.tile'),
          title: 'Payments',
          subtitle: 'New expenses and settlement disputes.',
          value: prefs.payments,
          enabled: prefs.pushEnabled,
          onChanged: (v) =>
              _safeUpdate(context, () => controller.setPayments(v)),
        ),
        AppSwitchTile(
          key: const Key('notifSettings.eventUpdates.tile'),
          title: 'Event updates',
          subtitle: 'When someone joins one of your events.',
          value: prefs.eventUpdates,
          enabled: prefs.pushEnabled,
          onChanged: (v) =>
              _safeUpdate(context, () => controller.setEventUpdates(v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSwitchTile(
          key: const Key('notifSettings.criticalOptIn.tile'),
          title: 'Allow urgent alerts to bypass Do Not Disturb',
          subtitle:
              'Required for 🚨 messages to ring through Focus / silent mode. '
              'You can revoke this at any time in iOS Focus settings or '
              'Android Do Not Disturb access.',
          value: prefs.criticalOptIn,
          // Only meaningful when urgent chat is enabled.
          enabled: prefs.pushEnabled && prefs.urgentChat,
          onChanged: (v) => _safeUpdate(
            context,
            () => controller.setCriticalOptIn(v),
            // Re-confirm only on enable so the user knows this is an
            // elevated permission (per Phase 4 plan). Disabling is silent.
            confirmationOnEnable: v
                ? 'Urgent alerts will bypass Do Not Disturb on this device.'
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _safeUpdate(
    BuildContext context,
    Future<void> Function() update, {
    String? confirmationOnEnable,
  }) async {
    try {
      await update();
      if (confirmationOnEnable != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(confirmationOnEnable)));
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save — try again'),
          backgroundColor: AppColors.terracotta,
        ),
      );
    }
  }
}
