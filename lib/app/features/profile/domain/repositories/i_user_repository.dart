import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

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
  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? displayName,
  });

  /// Adds an FCM token to `users/{uid}.fcmTokens` (idempotent via arrayUnion).
  Future<void> addFcmToken({required String uid, required String token});

  /// Removes an FCM token from `users/{uid}.fcmTokens` (idempotent).
  Future<void> removeFcmToken({required String uid, required String token});
}
