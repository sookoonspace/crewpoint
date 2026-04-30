/// Maps a Firebase Auth error code (the part after `auth/`) to the
/// user-facing copy CrewPoint shows in snackbars / form errors.
///
/// Pulled out as a top-level pure function so the popup-error mappings
/// added for web Apple sign-in can be unit-tested without instantiating
/// `FirebaseAuthService` (which would otherwise need a real Firebase
/// binding).
String firebaseAuthErrorMessage(String code) => switch (code) {
  'invalid-email' => 'The email address is invalid.',
  'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
  'user-not-found' => 'No account found with this email.',
  'email-already-in-use' => 'An account already exists with this email.',
  'weak-password' => 'Password must be at least 6 characters.',
  'network-request-failed' => 'Network error. Please check your connection.',
  'popup-blocked' =>
    'Pop-ups are blocked - please allow pop-ups for this site and try again.',
  'cancelled-popup-request' || 'popup-closed-by-user' => 'Sign-in cancelled.',
  'too-many-requests' =>
    'Too many attempts. Please wait a minute before trying again.',
  _ => 'An unexpected error occurred. Please try again.',
};
