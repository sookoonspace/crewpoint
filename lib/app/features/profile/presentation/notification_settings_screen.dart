import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
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
    final navigator = Navigator.of(context);

    return Scaffold(
      backgroundColor: context.cp.colors.background,
      appBar: CpTopBar(
        title: s.notifications,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
      body: uid == null
          ? CpEmptyState(icon: CpIcons.lock, title: s.signInRequired)
          : _Body(uid: uid),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final s = context.strings.profile;
    return switch (ref.watch(notificationPrefsProvider(uid))) {
      AsyncValue(:final value?) => ListView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: _PrefsForm(uid: uid, prefs: value),
          ),
        ],
      ),
      AsyncValue(error: != null) => CpErrorState(
        key: const Key('notifSettings.error'),
        title: s.notifLoadFailed,
        retryLabel: s.retry,
        retryKey: const Key('notifSettings.retry'),
        onRetry: () => ref.invalidate(notificationPrefsProvider(uid)),
      ),
      _ => CpLoadingState.rows(
        key: const Key('notifSettings.loading'),
        semanticLabel: s.notifications,
      ),
    };
  }
}

/// Switch rows in a card, padded so the switches line up with the card's
/// other rows.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return CpCard(
      padding: EdgeInsets.symmetric(
        horizontal: cp.space.lg,
        vertical: cp.space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: children,
      ),
    );
  }
}

void _showSaveError(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.strings.profile.notifSaveFailed)),
  );
}

class _PrefsForm extends ConsumerWidget {
  const _PrefsForm({required this.uid, required this.prefs});

  final String uid;
  final NotificationPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final s = context.strings.profile;
    final controller = ref.read(notificationPrefsProvider(uid).notifier);
    final on = prefs.pushEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.lg,
      children: [
        _SwitchCard(
          children: [
            CpSwitchRow(
              key: const Key('notifSettings.pushEnabled.tile'),
              title: s.notifPush,
              help: on ? s.notifPushOn : s.notifPushOff,
              value: on,
              onChanged: (v) =>
                  _safeUpdate(context, () => controller.setPushEnabled(v)),
            ),
          ],
        ),
        CpSectionHeader(title: s.notifCategories),
        _SwitchCard(
          children: [
            CpSwitchRow(
              key: const Key('notifSettings.urgentChat.tile'),
              title: s.notifUrgent,
              help: s.notifUrgentHelp,
              value: prefs.urgentChat,
              onChanged: on
                  ? (v) =>
                        _safeUpdate(context, () => controller.setUrgentChat(v))
                  : null,
            ),
            CpSwitchRow(
              key: const Key('notifSettings.taskUpdates.tile'),
              title: s.notifTasks,
              help: s.notifTasksHelp,
              value: prefs.taskUpdates,
              onChanged: on
                  ? (v) =>
                        _safeUpdate(context, () => controller.setTaskUpdates(v))
                  : null,
            ),
            CpSwitchRow(
              key: const Key('notifSettings.payments.tile'),
              title: s.notifPayments,
              help: s.notifPaymentsHelp,
              value: prefs.payments,
              onChanged: on
                  ? (v) => _safeUpdate(context, () => controller.setPayments(v))
                  : null,
            ),
            CpSwitchRow(
              key: const Key('notifSettings.eventUpdates.tile'),
              title: s.notifEvents,
              help: s.notifEventsHelp,
              value: prefs.eventUpdates,
              onChanged: on
                  ? (v) => _safeUpdate(
                      context,
                      () => controller.setEventUpdates(v),
                    )
                  : null,
            ),
          ],
        ),
        _QuietHoursCard(uid: uid, prefs: prefs),
        _SwitchCard(
          children: [
            CpSwitchRow(
              key: const Key('notifSettings.dailyDigest.tile'),
              title: s.notifDigest,
              help: s.notifDigestHelp,
              value: prefs.dailyDigest,
              onChanged: on
                  ? (v) =>
                        _safeUpdate(context, () => controller.setDailyDigest(v))
                  : null,
            ),
          ],
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
      _showSaveError(context);
    }
  }
}

String _formatMinute(int m) {
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h:$mm';
}

/// Phase 5 / 5.2 quiet-hours toggle. Enabling sets a default
/// 22:00-07:00 window in the device's IANA timezone (resolved via
/// `deviceTimezoneProvider` — native call to TimeZone.current on iOS /
/// TimeZone.getDefault() on Android; falls back to `'UTC'` when the
/// platform call fails). Server-side enforcement honours any window the
/// user picks with the Start and End rows.
class _QuietHoursCard extends ConsumerWidget {
  const _QuietHoursCard({required this.uid, required this.prefs});

  final String uid;
  final NotificationPrefs prefs;

  static const _defaultStartMinute = 22 * 60;
  static const _defaultEndMinute = 7 * 60;

  bool get _isEnabled =>
      prefs.quietHoursStart != null &&
      prefs.quietHoursEnd != null &&
      prefs.timezone != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final s = context.strings.profile;
    final controller = ref.read(notificationPrefsProvider(uid).notifier);
    final help = _isEnabled
        ? s.notifQuietOn(
            start: _formatMinute(prefs.quietHoursStart!),
            end: _formatMinute(prefs.quietHoursEnd!),
            zone: prefs.timezone!,
          )
        : s.notifQuietOff;
    return CpCard(
      child: CpRowGroup(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: cp.space.lg,
              vertical: cp.space.sm,
            ),
            child: CpSwitchRow(
              key: const Key('notifSettings.quietHours.tile'),
              title: s.notifQuiet,
              help: help,
              value: _isEnabled,
              onChanged: prefs.pushEnabled
                  ? (v) => _safeToggle(context, ref, controller, enable: v)
                  : null,
            ),
          ),
          if (_isEnabled) ...[
            _TimeRow(
              keyId: 'notifSettings.quietHours.start',
              label: s.notifQuietStart,
              minuteOfDay: prefs.quietHoursStart!,
              onPicked: (m) => _safeSetStart(context, controller, m),
            ),
            _TimeRow(
              keyId: 'notifSettings.quietHours.end',
              label: s.notifQuietEnd,
              minuteOfDay: prefs.quietHoursEnd!,
              onPicked: (m) => _safeSetEnd(context, controller, m),
            ),
          ],
        ],
      ),
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
      _showSaveError(context);
    }
  }
}

/// One quiet-hours endpoint: its label and "HH:MM". Tapping opens
/// Material's [showTimePicker], whose choice is handed to [onPicked] as a
/// minute of the day. The picker itself is covered by manual QA, since its
/// keyboard input mode is brittle in widget tests.
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

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return CpListRow(
      key: Key(keyId),
      title: label,
      trailing: Text(
        _formatMinute(minuteOfDay),
        style: cp.type.titleMedium.copyWith(color: cp.colors.text),
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
