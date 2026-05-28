import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:crewpoint_app/app/core/services/fcm_handler.dart';

/// Bridges `firebase_messaging` platform streams to [FcmHandler].
///
/// The handler holds the pure routing logic (foreground vs. tap, suppress
/// banner when already on chat). This bootstrap owns the lifecycle of the
/// subscriptions so [start] / [dispose] can be tested without touching the
/// real `FirebaseMessaging` channel — production wiring injects
/// `FirebaseMessaging.instance.onMessage`, `.onMessageOpenedApp`, and
/// `.getInitialMessage` from `main.dart`.
class FcmHandlerBootstrap {
  FcmHandlerBootstrap({
    required FcmHandler handler,
    required Stream<RemoteMessage> onMessage,
    required Stream<RemoteMessage> onMessageOpenedApp,
    required Future<RemoteMessage?> Function() getInitialMessage,
  }) : _handler = handler,
       _onMessage = onMessage,
       _onMessageOpenedApp = onMessageOpenedApp,
       _getInitialMessage = getInitialMessage;

  final FcmHandler _handler;
  final Stream<RemoteMessage> _onMessage;
  final Stream<RemoteMessage> _onMessageOpenedApp;
  final Future<RemoteMessage?> Function() _getInitialMessage;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  /// Subscribes to the two streams and processes the cold-start tap (if
  /// any). Safe to await once — re-calling start without dispose will leak
  /// the previous subscriptions.
  Future<void> start() async {
    _onMessageSub = _onMessage.listen((msg) {
      _handler.handleForegroundMessage(
        title: msg.notification?.title ?? '',
        body: msg.notification?.body ?? '',
        data: _stringifyData(msg.data),
      );
    });
    _onOpenedSub = _onMessageOpenedApp.listen((msg) {
      _handler.handleTap(data: _stringifyData(msg.data));
    });
    final initial = await _getInitialMessage();
    if (initial != null) {
      _handler.handleTap(data: _stringifyData(initial.data));
    }
  }

  /// Cancels both stream subscriptions. Idempotent.
  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    _onMessageSub = null;
    _onOpenedSub = null;
  }

  /// `RemoteMessage.data` is `Map<String, dynamic>` on the platform channel
  /// boundary even though FCM only ever sends strings — coerce here so the
  /// handler signature stays clean.
  Map<String, String> _stringifyData(Map<String, dynamic> data) {
    return {
      for (final entry in data.entries)
        entry.key: entry.value?.toString() ?? '',
    };
  }
}
