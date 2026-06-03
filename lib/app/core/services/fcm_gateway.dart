import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

  /// Returns the current FCM token, or null if not available.
  Future<String?> getToken();

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
  static const _apnsMaxAttempts = 5;
  static const _apnsRetryDelay = Duration(milliseconds: 300);

  /// Sentinel returned for non-APNs platforms (Android, web, desktop) so
  /// the [FcmService.attach] chain doesn't trip the "null → skip" guard
  /// there.
  static const _nonIosSentinel = 'non-ios-no-apns';

  @override
  Future<String?> getApnsToken() async {
    if (kIsWeb || !Platform.isIOS) return _nonIosSentinel;
    for (var i = 0; i < _apnsMaxAttempts; i++) {
      final token = await _messaging.getAPNSToken();
      if (token != null) return token;
      if (i < _apnsMaxAttempts - 1) {
        await Future<void>.delayed(_apnsRetryDelay);
      }
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
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
