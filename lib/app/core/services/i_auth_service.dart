/// Abstract auth service interface.
/// Concrete implementations wrap Firebase Auth or other providers.
abstract class IAuthService {
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthResult> signInWithGoogle();

  Future<AuthResult> signInWithApple();

  Future<void> signOut();

  Future<void> deleteAccount();

  Stream<AuthUser?> get authStateChanges;

  AuthUser? get currentUser;
}

/// Minimal auth user representation independent of Firebase.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Result of an auth operation.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);
  final AuthUser user;
}

class AuthResultFailure extends AuthResult {
  const AuthResultFailure(this.message);
  final String message;
}
