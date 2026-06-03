import 'dart:async';
import 'dart:developer';

import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
import 'package:crewpoint_app/app/core/services/notification_channels.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// Owns the FCM token lifecycle:
/// * `attach(uid)` after sign-in — requests permission, fetches APNs (iOS),
///   fetches FCM token, writes it to `users/{uid}.fcmTokens`, and starts
///   listening for refreshes.
/// * `detach(uid)` before sign-out — removes the current token from the
///   user doc, then deletes the local token. (Order matters: deleting first
///   would leave a stale token in Firestore the user no longer owns.)
class FcmService {
  FcmService({
    required IFcmGateway gateway,
    required IUserRepository userRepository,
    INotificationChannels notificationChannels =
        const NoOpNotificationChannels(),
  }) : _gateway = gateway,
       _userRepository = userRepository,
       _notificationChannels = notificationChannels;

  final IFcmGateway _gateway;
  final IUserRepository _userRepository;
  final INotificationChannels _notificationChannels;
  StreamSubscription<String>? _refreshSub;
  String? _currentToken;
  String? _attachedUid;

  /// Returns true if a token was successfully written. Short-circuits when
  /// the user's [NotificationPrefs.pushEnabled] is false — neither the
  /// OS permission prompt nor the token write fires, so we don't end up
  /// holding a token the user has explicitly disabled.
  Future<bool> attach({required String uid}) async {
    try {
      final prefs = await _userRepository.getNotificationPrefs(uid);
      if (!prefs.pushEnabled) {
        log('FCM attach skipped — push disabled by user $uid', name: 'fcm');
        return false;
      }
      final granted = await _gateway.requestPermission();
      if (!granted) {
        log('FCM permission denied for $uid', name: 'fcm');
        return false;
      }
      // iOS: explicitly trigger registerForRemoteNotifications. The
      // firebase_messaging plugin only calls this at app launch, when
      // authorization is `notDetermined` for auth-gated apps — iOS
      // silently no-ops it and APNs never registers. Calling here, after
      // permission was just granted, is what actually starts the APNs
      // handshake. No-op on Android / web / desktop.
      await _gateway.triggerApnsRegistration();
      // Android: declare notification channels before the first push can
      // arrive (API 26+ requirement). iOS / web / desktop short-circuit
      // inside the adapter; failure is swallowed there too — channel
      // setup must never block token registration.
      await _notificationChannels.registerAll();

      // Wire the refresh listener BEFORE the initial token fetch so a
      // first-launch APNs race on iOS still lands the token. The OS
      // may take several seconds (sometimes 10s+) to hand back an APNs
      // token after permission grant; getToken() in that window throws
      // `apns-token-not-set`, but `onTokenRefresh` fires once FCM has
      // both APNs + its own token registered. The listener writes the
      // token whenever it eventually arrives.
      _attachedUid = uid;
      await _refreshSub?.cancel();
      _refreshSub = _gateway.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        try {
          await _userRepository.addFcmToken(uid: uid, token: newToken);
          log('FCM token written via refresh for $uid', name: 'fcm');
        } catch (e, st) {
          log(
            'FCM refresh write failed for $uid',
            error: e,
            stackTrace: st,
            name: 'fcm',
          );
        }
      });

      // iOS: APNs token must resolve before getToken(). The gateway
      // polls briefly and returns null when APNs can't deliver one
      // (iOS Simulator, or a first-launch race that exceeds the poll
      // budget). The refresh listener above is already in place to
      // catch the eventual token, so we just log and return false on
      // null. On Android / web the gateway returns a sentinel and we
      // fall straight through.
      final apnsToken = await _gateway.getApnsToken();
      if (apnsToken == null) {
        log(
          'FCM initial token deferred for $uid — APNs not ready yet; '
          'refresh listener will catch it once registered',
          name: 'fcm',
        );
        return false;
      }
      final token = await _gateway.getToken();
      if (token == null) {
        log(
          'FCM initial token unavailable for $uid (refresh listener '
          'will catch a later token)',
          name: 'fcm',
        );
        return false;
      }
      _currentToken = token;
      await _userRepository.addFcmToken(uid: uid, token: token);
      return true;
    } catch (e, st) {
      log('FCM attach failed', error: e, stackTrace: st, name: 'fcm');
      return false;
    }
  }

  /// Reverses [attach]. The arrayRemove must run before deleteToken so the
  /// security rules still recognize the caller as the doc owner.
  Future<void> detach({required String uid}) async {
    final token = _currentToken;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (token != null) {
      await _userRepository.removeFcmToken(uid: uid, token: token);
    }
    await _gateway.deleteToken();
    _currentToken = null;
    _attachedUid = null;
  }

  String? get currentToken => _currentToken;
  String? get attachedUid => _attachedUid;

  Future<void> dispose() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
  }
}
