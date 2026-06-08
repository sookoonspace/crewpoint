import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Test seam over `package:firebase_messaging`.
///
/// Tests provide a fake to verify the [FcmService] token-lifecycle contract
/// without touching the real platform channel.
abstract class IFcmGateway {
  /// iOS: returns the APNs token (polled briefly if not yet set — the OS
  /// fetches it asynchronously after permission grants). Returns null
  /// when the token can't be resolved (most commonly: iOS Simulator,
  /// which cannot reach APNs). [FcmService.attach] treats null as
  /// "device cannot receive pushes" and short-circuits the rest of the
  /// flow rather than calling [getToken] (which would otherwise throw
  /// `apns-token-not-set`).
  ///
  /// Android / web: returns a non-null sentinel so the caller can chain
  /// straight through to [getToken] — APNs is not in the picture there.
  Future<String?> getApnsToken();

  /// Requests notification permission. Returns whether the user accepted
  /// (treat `provisional` as accepted).
  Future<bool> requestPermission();

  /// iOS-only: explicitly calls `UIApplication.registerForRemoteNotifications`.
  ///
  /// The `firebase_messaging` plugin only calls this **once**, during
  /// `application_onDidFinishLaunchingNotification` at app launch (see
  /// FLTFirebaseMessagingPlugin.m:308). For auth-gated apps that request
  /// permission later (after sign-in), authorization is `notDetermined`
  /// at that point and iOS silently no-ops the call — APNs registration
  /// never starts. Calling this explicitly after [requestPermission]
  /// grants forces iOS to register and gives us the APNs token via the
  /// `didRegisterForRemoteNotificationsWithDeviceToken` callback chain.
  ///
  /// No-op on non-iOS platforms.
  Future<void> triggerApnsRegistration();

  /// Returns the current FCM token, or null if not available.
  ///
  /// Web requires [vapidKey] (the application server's VAPID public
  /// key); the underlying plugin rejects the call without it. Mobile /
  /// desktop ignore the parameter.
  Future<String?> getToken({String? vapidKey});

  /// Stream of token-refresh events.
  Stream<String> get onTokenRefresh;

  /// Deletes the local FCM token (called on sign-out).
  Future<void> deleteToken();
}

/// Real implementation wrapping [FirebaseMessaging.instance].
class FirebaseFcmGateway implements IFcmGateway {
  FirebaseFcmGateway({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// APNs polling: up to ~1.5s total (5 attempts × 300ms). Real devices
  /// usually hand back a token on the first call; the retries cover the
  /// post-permission-grant race. Simulator builds will burn the whole
  /// budget and then fall through to `null` — that's fine, the caller
  /// short-circuits.
  static const _apnsMaxAttempts = 30;
  static const _apnsRetryDelay = Duration(milliseconds: 300);

  /// Sentinel returned for non-APNs platforms (Android, web, desktop) so
  /// the [FcmService.attach] chain doesn't trip the "null → skip" guard
  /// there.
  static const _nonIosSentinel = 'non-ios-no-apns';

  /// `MethodChannel` to the Swift `registerForRemoteNotifications`
  /// trigger registered in `ios/Runner/AppDelegate.swift`.
  static const _apnsChannel = MethodChannel('crewpoint/apns');

  @override
  Future<String?> getApnsToken() async {
    if (kIsWeb || !Platform.isIOS) return _nonIosSentinel;
    for (var i = 0; i < _apnsMaxAttempts; i++) {
      final token = await _messaging.getAPNSToken();
      if (token != null) {
        log(
          'APNs token acquired after ${i + 1} poll(s) '
          '(${(i + 1) * _apnsRetryDelay.inMilliseconds}ms)',
          name: 'fcm.apns',
        );
        return token;
      }
      if (i < _apnsMaxAttempts - 1) {
        await Future<void>.delayed(_apnsRetryDelay);
      }
    }
    // Polling exhausted — dump everything Dart can see about why iOS
    // didn't hand back a token. Most informative pieces:
    //  - `authorizationStatus`: confirms the user actually granted
    //    permission. `denied` or `notDetermined` here means we never
    //    asked / they refused, so `registerForRemoteNotifications` is
    //    a no-op upstream.
    //  - `alert / badge / sound`: any "disabled" here points at iOS
    //    Settings restrictions even though authorization is granted.
    try {
      final settings = await _messaging.getNotificationSettings();
      log(
        'APNs polling EXHAUSTED ($_apnsMaxAttempts × '
        '${_apnsRetryDelay.inMilliseconds}ms = '
        '${_apnsMaxAttempts * _apnsRetryDelay.inMilliseconds}ms). '
        'authorizationStatus=${settings.authorizationStatus.name}, '
        'alert=${settings.alert.name}, '
        'badge=${settings.badge.name}, '
        'sound=${settings.sound.name}, '
        'notificationCenter=${settings.notificationCenter.name}, '
        'lockScreen=${settings.lockScreen.name}, '
        'criticalAlert=${settings.criticalAlert.name}',
        name: 'fcm.apns',
      );
    } catch (e, st) {
      log(
        'APNs polling exhausted; getNotificationSettings also failed',
        error: e,
        stackTrace: st,
        name: 'fcm.apns',
      );
    }
    return null;
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> triggerApnsRegistration() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _apnsChannel.invokeMethod<void>('registerForRemoteNotifications');
      log(
        'triggerApnsRegistration() invoked native registerForRemoteNotifications',
        name: 'fcm.apns',
      );
    } catch (e, st) {
      log(
        'triggerApnsRegistration() MethodChannel call failed',
        error: e,
        stackTrace: st,
        name: 'fcm.apns',
      );
    }
  }

  @override
  Future<String?> getToken({String? vapidKey}) =>
      _messaging.getToken(vapidKey: vapidKey);

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
