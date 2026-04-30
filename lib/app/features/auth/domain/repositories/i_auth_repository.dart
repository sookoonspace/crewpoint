import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/auth_failure.dart';

/// Abstract auth repository — swap implementations without touching UI.
abstract class IAuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;

  Future<({AppUser? user, AuthFailure? failure})> signInWithEmail({
    required String email,
    required String password,
  });

  Future<({AppUser? user, AuthFailure? failure})> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<({AppUser? user, AuthFailure? failure})> signInWithGoogle();
  Future<({AppUser? user, AuthFailure? failure})> signInWithApple();
  Future<void> signOut();
  Future<void> deleteAccount();

  /// Sends a verification email to the currently signed-in user.
  /// Throws on failure so the caller can surface the message.
  Future<void> sendEmailVerification();

  /// Forces a refresh of the local user's `emailVerified` flag from the
  /// server, then returns the refreshed [AppUser] (or null if signed out).
  Future<AppUser?> reloadCurrentUser();
}
