/// Typed auth failure models for structured error handling.
enum AuthFailureType {
  invalidEmail,
  wrongPassword,
  userNotFound,
  emailAlreadyInUse,
  weakPassword,
  networkError,
  cancelled,
  unknown,
}

class AuthFailure {
  const AuthFailure({
    required this.type,
    required this.message,
    this.suggestedProvider,
  });

  final AuthFailureType type;
  final String message;

  /// When non-null, password sign-in failed for an email that's
  /// registered via this OAuth provider instead. Drives the
  /// "this email signs in with Apple — tap that instead" UX.
  /// Set only when `fetchSignInMethodsForEmail` returns an
  /// OAuth-only provider list AND `password` is absent. Always
  /// null when Firebase's email enumeration protection is on
  /// (the fetch returns empty in that case).
  final String? suggestedProvider;

  @override
  String toString() =>
      'AuthFailure($type: $message${suggestedProvider != null ? ', suggested=$suggestedProvider' : ''})';
}
