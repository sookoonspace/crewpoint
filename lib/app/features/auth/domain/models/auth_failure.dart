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
  const AuthFailure({required this.type, required this.message});

  final AuthFailureType type;
  final String message;

  @override
  String toString() => 'AuthFailure($type: $message)';
}
