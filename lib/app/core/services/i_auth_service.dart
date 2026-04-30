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

  /// Sends a verification email to the currently signed-in user.
  /// Throws on failure (e.g. `too-many-requests` from Firebase).
  Future<void> sendEmailVerification();

  /// Forces a refresh of the local user's `emailVerified` flag from
  /// the server. Call after the user reports they clicked the link.
  Future<void> reloadCurrentUser();

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
    this.emailVerified = false,
    this.providerIds = const [],
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// True iff Firebase considers this user's email verified.
  /// OAuth providers (Google, Apple, etc.) issue verified-email tokens;
  /// fresh email/password accounts are unverified until the user clicks
  /// the verification link.
  final bool emailVerified;

  /// Firebase provider IDs attached to this user (`password`, `apple.com`,
  /// `google.com`, ...). Drives the "Verify your email" banner — it
  /// only shows for password-only accounts that haven't verified yet.
  final List<String> providerIds;
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
