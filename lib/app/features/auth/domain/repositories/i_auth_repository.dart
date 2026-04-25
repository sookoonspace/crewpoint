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
}
