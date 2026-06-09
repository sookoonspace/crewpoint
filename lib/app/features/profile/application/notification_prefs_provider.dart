import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';

/// Riverpod controller for the user's notification preferences. State is
/// the latest [NotificationPrefs] read from the user repo, wrapped in an
/// [AsyncValue] so the settings screen can render loading/error states.
///
/// `setPushEnabled(false)` is the master kill-switch and also fires
/// `FcmService.detach(uid)` so the device drops its token immediately
/// (no waiting for the next CF read).
class NotificationPrefsNotifier extends AsyncNotifier<NotificationPrefs> {
  NotificationPrefsNotifier(this.uid);

  /// Family argument — the user uid whose prefs this notifier owns.
  final String uid;

  @override
  Future<NotificationPrefs> build() async {
    final repo = ref.watch(userRepositoryProvider);
    return repo.getNotificationPrefs(uid);
  }

  Future<void> setPushEnabled(bool value) async {
    await _update((prefs) => prefs.copyWith(pushEnabled: value));
    if (!value) {
      // Drop the local token so the user stops receiving pushes on this
      // device before the next CF lookup.
      unawaited(_safeDetach());
    }
  }

  Future<void> setUrgentChat(bool value) async {
    await _update((prefs) => prefs.copyWith(urgentChat: value));
  }

  Future<void> setTaskUpdates(bool value) async {
    await _update((prefs) => prefs.copyWith(taskUpdates: value));
  }

  Future<void> setPayments(bool value) async {
    await _update((prefs) => prefs.copyWith(payments: value));
  }

  Future<void> setEventUpdates(bool value) async {
    await _update((prefs) => prefs.copyWith(eventUpdates: value));
  }

  /// Toggles the Phase 6.1 daily-digest opt-in. CF reads this
  /// server-side when picking digest recipients each hour.
  Future<void> setDailyDigest(bool value) async {
    await _update((prefs) => prefs.copyWith(dailyDigest: value));
  }

  /// Sets the recipient's preferred notification locale (BCP-47).
  /// Pass `null` to revert to the server default (English).
  Future<void> setLocale(String? value) async {
    await _update((prefs) {
      // copyWith can't transition non-null → null for nullable params;
      // hand-build when clearing.
      if (value == null) {
        return NotificationPrefs(
          pushEnabled: prefs.pushEnabled,
          urgentChat: prefs.urgentChat,
          taskUpdates: prefs.taskUpdates,
          payments: prefs.payments,
          eventUpdates: prefs.eventUpdates,
          quietHoursStart: prefs.quietHoursStart,
          quietHoursEnd: prefs.quietHoursEnd,
          timezone: prefs.timezone,
        );
      }
      return prefs.copyWith(locale: value);
    });
  }

  /// Sets (or replaces) the quiet-hours window. Pass `null` for all
  /// three to clear the window entirely (CF treats absent fields as
  /// "no quiet hours").
  Future<void> setQuietHours({
    required int? startMinute,
    required int? endMinute,
    required String? timezone,
  }) async {
    final allNull =
        startMinute == null && endMinute == null && timezone == null;
    await _update((prefs) {
      if (allNull) return prefs.withQuietHoursCleared();
      return prefs.copyWith(
        quietHoursStart: startMinute,
        quietHoursEnd: endMinute,
        timezone: timezone,
      );
    });
  }

  Future<void> _update(
    NotificationPrefs Function(NotificationPrefs prefs) transform,
  ) async {
    final current = state.value ?? const NotificationPrefs();
    final next = transform(current);
    state = AsyncData(next);
    try {
      await ref
          .read(userRepositoryProvider)
          .updateNotificationPrefs(uid: uid, prefs: next);
    } catch (e, st) {
      log(
        'failed to update notificationPrefs for $uid',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
      // Roll back optimistic state.
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> _safeDetach() async {
    try {
      await ref.read(fcmServiceProvider).detach(uid: uid);
    } catch (e, st) {
      log(
        'fcm detach after disable failed for $uid',
        error: e,
        stackTrace: st,
        name: 'fcm',
      );
    }
  }
}

final notificationPrefsProvider =
    AsyncNotifierProvider.family<
      NotificationPrefsNotifier,
      NotificationPrefs,
      String
    >(NotificationPrefsNotifier.new);
