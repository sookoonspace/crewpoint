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
        _QuietHoursTile(uid: uid, prefs: prefs),
        const SizedBox(height: AppSpacing.lg),
        AppSwitchTile(
          key: const Key('notifSettings.dailyDigest.tile'),
          title: 'Daily digest',
          subtitle:
              'Morning summary of unread chat, pending tasks, and open '
              'settlements. Sent at 9:00 in your timezone.',
          value: prefs.dailyDigest,
          enabled: prefs.pushEnabled,
          onChanged: (v) =>
              _safeUpdate(context, () => controller.setDailyDigest(v)),
        ),
      ],
    );
  }

  Future<void> _safeUpdate(
    BuildContext context,
    Future<void> Function() update,
  ) async {
    try {
      await update();
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

/// Phase 5 / 5.2 quiet-hours toggle. Enabling sets a default
/// 22:00-07:00 window in the device's IANA timezone (resolved via
/// `deviceTimezoneProvider` — native call to TimeZone.current on iOS /
/// TimeZone.getDefault() on Android; falls back to `'UTC'` when the
/// platform call fails). Phase 5.2 follow-up adds a custom-window
/// picker; server-side enforcement already honours any window the user
/// / picker writes.
class _QuietHoursTile extends ConsumerWidget {
  const _QuietHoursTile({required this.uid, required this.prefs});

  final String uid;
  final NotificationPrefs prefs;

  static const _defaultStartMinute = 22 * 60;
  static const _defaultEndMinute = 7 * 60;

  bool get _isEnabled =>
      prefs.quietHoursStart != null &&
      prefs.quietHoursEnd != null &&
      prefs.timezone != null;

  String _formatMinute(int m) {
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$h:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationPrefsProvider(uid).notifier);
    final subtitle = _isEnabled
        ? 'Muted ${_formatMinute(prefs.quietHoursStart!)}'
              ' – ${_formatMinute(prefs.quietHoursEnd!)}'
              ' (${prefs.timezone})'
        : 'Suppress non-urgent push during a daily window.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSwitchTile(
          key: const Key('notifSettings.quietHours.tile'),
          title: 'Quiet hours',
          subtitle: subtitle,
          value: _isEnabled,
          enabled: prefs.pushEnabled,
          onChanged: (v) => _safeToggle(context, ref, controller, enable: v),
        ),
        if (_isEnabled) ...[
          _TimeRow(
            keyId: 'notifSettings.quietHours.start',
            label: 'Start',
            minuteOfDay: prefs.quietHoursStart!,
            onPicked: (m) => _safeSetStart(context, controller, m),
          ),
          _TimeRow(
            keyId: 'notifSettings.quietHours.end',
            label: 'End',
            minuteOfDay: prefs.quietHoursEnd!,
            onPicked: (m) => _safeSetEnd(context, controller, m),
          ),
        ],
      ],
    );
  }

  Future<void> _safeSetStart(
    BuildContext context,
    NotificationPrefsNotifier controller,
    int newStartMinute,
  ) async {
    try {
      await controller.setQuietHours(
        startMinute: newStartMinute,
        endMinute: prefs.quietHoursEnd,
        timezone: prefs.timezone,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSaveError(context);
    }
  }

  Future<void> _safeSetEnd(
    BuildContext context,
    NotificationPrefsNotifier controller,
    int newEndMinute,
  ) async {
    try {
      await controller.setQuietHours(
        startMinute: prefs.quietHoursStart,
        endMinute: newEndMinute,
        timezone: prefs.timezone,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSaveError(context);
    }
  }

  void _showSaveError(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not save — try again'),
        backgroundColor: AppColors.terracotta,
      ),
    );
  }

  Future<void> _safeToggle(
    BuildContext context,
    WidgetRef ref,
    NotificationPrefsNotifier controller, {
    required bool enable,
  }) async {
    try {
      if (enable) {
        final tz = await ref.read(deviceTimezoneProvider).getLocalTimezone();
        await controller.setQuietHours(
          startMinute: _defaultStartMinute,
          endMinute: _defaultEndMinute,
          timezone: tz,
        );
      } else {
        await controller.setQuietHours(
          startMinute: null,
          endMinute: null,
          timezone: null,
        );
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

/// One quiet-hours endpoint row — leading label + trailing "HH:MM"
/// display. Tap opens Material's [showTimePicker]; the chosen
/// [TimeOfDay] is converted to a minute-of-day int and handed to
/// [onPicked]. The `showTimePicker` dialog itself is not exercised in
/// widget tests (Material's input-mode keyboard interaction is brittle
/// in the test harness); manual QA covers the dialog.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.keyId,
    required this.label,
    required this.minuteOfDay,
    required this.onPicked,
  });

  final String keyId;
  final String label;
  final int minuteOfDay;
  final ValueChanged<int> onPicked;

  String _format(int m) {
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$h:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key(keyId),
      title: Text(label),
      trailing: Text(
        _format(minuteOfDay),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: minuteOfDay ~/ 60,
            minute: minuteOfDay % 60,
          ),
        );
        if (picked == null) return;
        onPicked(picked.hour * 60 + picked.minute);
      },
    );
  }
}
