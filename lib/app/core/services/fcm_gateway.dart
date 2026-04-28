import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Test seam over `package:firebase_messaging`.
///
/// Tests provide a fake to verify the [FcmService] token-lifecycle contract
/// without touching the real platform channel.
abstract class IFcmGateway {
  /// iOS only: returns the APNs token. Must complete before [getToken].
  /// Android: implementations should return a non-null sentinel (or the
  /// real token if the platform exposes one) so callers can chain freely.
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

  @override
  Future<String?> getApnsToken() => _messaging.getAPNSToken();

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
