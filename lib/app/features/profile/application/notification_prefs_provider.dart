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
