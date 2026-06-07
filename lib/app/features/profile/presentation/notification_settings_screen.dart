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

/// Per-app-launch query for "is the OS willing to let our urgent channel
/// bypass DND on this device?". Android-only; iOS / web / desktop always
/// resolve true (the entitlement-vs-grant gate lives at build time, not
/// runtime). Used to surface the non-blocking DND warning when the user
/// has opted in but the OS has not yet been told yes.
final _dndAccessGrantedProvider = FutureProvider<bool>((ref) async {
  return ref.watch(notificationChannelsProvider).isDndAccessGranted();
});

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
        if (prefs.criticalOptIn) _CriticalOptInDndWarning(),
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

/// Non-blocking banner shown beneath the criticalOptIn tile when the
/// user has opted in but the host OS has not yet granted DND-bypass
/// access (Android-only — iOS gates this at build time via the
/// `critical-alerts` entitlement). Tapping the CTA opens the system
/// "Do Not Disturb access" settings page; the screen re-checks on
/// resume via the `_dndAccessGrantedProvider` future invalidating
/// itself on rebuild.
class _CriticalOptInDndWarning extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGranted = ref.watch(_dndAccessGrantedProvider);
    // Treat the loading / error states as granted so we don't flash a
    // warning on first build. A real "not granted" eventually replaces it.
    final granted = asyncGranted.maybeWhen(data: (v) => v, orElse: () => true);
    if (granted) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      key: const Key('notifSettings.criticalOptIn.dndWarning'),
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Card(
        elevation: 0,
        color: AppColors.terracottaLight.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.terracotta, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.terracotta,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Do Not Disturb access not granted',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Urgent alerts will be delivered, but they cannot '
                      'ring through Do Not Disturb until you grant access '
                      'in system settings.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key(
                          'notifSettings.criticalOptIn.grantDnd.cta',
                        ),
                        onPressed: () async {
                          await ref
                              .read(notificationChannelsProvider)
                              .requestDndAccess();
                          // Re-query after the user returns from the
                          // system settings sheet so the banner can
                          // dismiss itself once permission lands.
                          ref.invalidate(_dndAccessGrantedProvider);
                        },
                        child: const Text('Grant access'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
