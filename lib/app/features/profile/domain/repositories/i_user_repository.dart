import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';

/// Abstract user profile repository.
/// Concrete implementations can use Firestore, mock, or any backend.
abstract class IUserRepository {
  /// Fetches user profile by UID.
  Future<AppUser?> getUser(String uid);

  /// Saves/updates profile fields. Uses merge semantics.
  Future<void> saveProfile({
    required String uid,
    required String displayName,
    String? photoUrl,
    String? paymentMethod,
    String? paymentHandle,
    String? venmoHandle,
    String? cashappHandle,
  });

  /// Creates user document if it doesn't exist yet (first login).
  ///
  /// [photoUrl] is written to the public doc when non-null (omitted otherwise).
  /// [providerIds] (e.g. `['google.com']`) is written to the private subdoc.
  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    List<String> providerIds = const [],
  });

  /// Adds an FCM token to `users/{uid}/private/profile.fcmTokens`
  /// (idempotent via arrayUnion). [platform] tags the token by the
  /// platform that owns it (`'mobile'` or `'web'`) so multi-platform
  /// installs can be reasoned about server-side. Storage shape is
  /// `{value, platform}` since Phase 6.2 — the CF reader still accepts
  /// legacy plain-string entries for pre-migration installs.
  Future<void> addFcmToken({
    required String uid,
    required String token,
    required String platform,
  });

  /// Removes an FCM token from `users/{uid}/private/profile.fcmTokens`.
  /// Removes the new `{value, platform}` shape; legacy plain-string
  /// entries stay until the CF prunes them on the next failed send.
  Future<void> removeFcmToken({
    required String uid,
    required String token,
    required String platform,
  });

  /// Reads the user's notification preferences from
  /// `users/{uid}/private/profile.notificationPrefs`. Returns
  /// [NotificationPrefs.fromMap]-defaults when the doc / field is missing
  /// so callers never need to null-check.
  Future<NotificationPrefs> getNotificationPrefs(String uid);

  /// Writes the user's notification preferences (merge semantics).
  Future<void> updateNotificationPrefs({
    required String uid,
    required NotificationPrefs prefs,
  });
}
