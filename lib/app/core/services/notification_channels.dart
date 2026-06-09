import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Test seam over the native Android notification-channel registration
/// platform channel.
///
/// Android 8.0 (API 26) requires every notification to be tagged with a
/// channel id; channels must be declared by the host app before the first
/// matching push lands. Flutter has no first-party channel API, so we ship
/// a small `MethodChannel` to a Kotlin handler in
/// `android/app/src/main/kotlin/.../MainActivity.kt` that calls
/// `NotificationManager.createNotificationChannel(...)` for each entry in
/// [kNotificationChannels].
///
/// Production wires [MethodChannelNotificationChannels]. Tests inject a
/// recording fake to assert the service's registration contract without
/// touching the platform channel. iOS / web / desktop builds run through
/// [MethodChannelNotificationChannels.registerAll] but short-circuit — the
/// concept does not exist on those platforms.
abstract class INotificationChannels {
  /// Registers every channel in [kNotificationChannels]. Idempotent —
  /// Android replaces an existing channel definition with the same id,
  /// non-Android targets no-op.
  Future<void> registerAll();
}

/// Importance bucket. Mirrors `android.app.NotificationManager.IMPORTANCE_*`
/// integer constants. Only the values we actually use are listed.
enum NotificationChannelImportance {
  /// `IMPORTANCE_DEFAULT` — makes a sound; appears in shade + status bar.
  default_(3),

  /// `IMPORTANCE_HIGH` — heads-up; the bar for `crewpoint_chat_urgent`.
  /// Phase 4 layers `setBypassDnd(true)` on top once the user grants
  /// `NOTIFICATION_POLICY_ACCESS_GRANTED`.
  high(4);

  const NotificationChannelImportance(this.value);

  final int value;
}

/// Single channel spec — serialised to a `Map<String, Object>` for the
/// `MethodChannel` jump.
@immutable
class NotificationChannelSpec {
  const NotificationChannelSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
  });

  final String id;
  final String name;
  final String description;
  final NotificationChannelImportance importance;

  Map<String, Object> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'importance': importance.value,
  };
}

/// Static channel registry. Adding a new category in a later phase means
/// (a) appending an entry here and (b) routing the CF to its `id` —
/// nothing else changes.
const List<NotificationChannelSpec> kNotificationChannels = [
  NotificationChannelSpec(
    id: 'crewpoint_chat_urgent',
    name: 'Urgent chat',
    description: 'High-priority chat alerts marked 🚨 by the sender.',
    importance: NotificationChannelImportance.high,
  ),
  NotificationChannelSpec(
    id: 'crewpoint_chat_general',
    name: 'Chat',
    description: 'Regular chat messages in your events.',
    importance: NotificationChannelImportance.default_,
  ),
  NotificationChannelSpec(
    id: 'crewpoint_tasks',
    name: 'Tasks',
    description: 'Task assignments and due-date reminders.',
    importance: NotificationChannelImportance.default_,
  ),
  NotificationChannelSpec(
    id: 'crewpoint_events',
    name: 'Event updates',
    description: 'New members, invite responses, event-level changes.',
    importance: NotificationChannelImportance.default_,
  ),
  NotificationChannelSpec(
    id: 'crewpoint_payments',
    name: 'Payments',
    description: 'Expense additions and settlement disputes.',
    importance: NotificationChannelImportance.default_,
  ),
  NotificationChannelSpec(
    id: 'crewpoint_digest',
    name: 'Daily digest',
    description: 'Morning summary of unread chat, tasks, and settlements.',
    importance: NotificationChannelImportance.default_,
  ),
];

/// No-op fallback. Used as the default in [FcmService] (so existing test
/// setups stay green) and as a safety net if a future Riverpod override
/// needs to disable channel registration entirely.
class NoOpNotificationChannels implements INotificationChannels {
  const NoOpNotificationChannels();

  @override
  Future<void> registerAll() async {}
}

/// Production adapter. Ships the entire channel registry to the Kotlin
/// `MainActivity` handler over `MethodChannel('crewpoint/notification_channels')`.
/// Native handler calls `NotificationManager.createNotificationChannel(...)`
/// per entry; replays are idempotent.
///
/// Platform failures are caught + logged — channel registration is best-
/// effort device setup and must never crash the host. iOS / web / desktop
/// short-circuit at the [Platform] check.
class MethodChannelNotificationChannels implements INotificationChannels {
  const MethodChannelNotificationChannels({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'crewpoint/notification_channels';
  static const String registerMethod = 'registerChannels';

  final MethodChannel _channel;

  @override
  Future<void> registerAll() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(registerMethod, {
        'channels': kNotificationChannels.map((c) => c.toMap()).toList(),
      });
    } catch (e, st) {
      log(
        'Notification channel registration failed',
        error: e,
        stackTrace: st,
        name: 'fcm',
      );
    }
  }
}
