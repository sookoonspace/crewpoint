import 'dart:async';
import 'dart:developer';

import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
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
  }) : _gateway = gateway,
       _userRepository = userRepository;

  final IFcmGateway _gateway;
  final IUserRepository _userRepository;
  StreamSubscription<String>? _refreshSub;
  String? _currentToken;
  String? _attachedUid;

  /// Returns true if a token was successfully written.
  Future<bool> attach({required String uid}) async {
    try {
      final granted = await _gateway.requestPermission();
      if (!granted) {
        log('FCM permission denied for $uid', name: 'fcm');
        return false;
      }
      // iOS: APNs token must resolve before getToken().
      await _gateway.getApnsToken();
      final token = await _gateway.getToken();
      if (token == null) {
        log('FCM token unavailable for $uid', name: 'fcm');
        return false;
      }
      _currentToken = token;
      _attachedUid = uid;
      await _userRepository.addFcmToken(uid: uid, token: token);
      _refreshSub = _gateway.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        await _userRepository.addFcmToken(uid: uid, token: newToken);
      });
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
