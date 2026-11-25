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

  /// Returns the Firebase sign-in provider IDs registered for [email]
  /// (`password`, `apple.com`, `google.com`, ...).
  ///
  /// Best-effort: returns an empty list when Firebase's email
  /// enumeration protection is on (default in newer projects), when
  /// the email has no account, or on any other failure. Callers must
  /// not branch on "empty list = no account" — empty is also the
  /// privacy-protected response and conflating the two would leak
  /// account existence.
  Future<List<String>> fetchSignInMethodsForEmail(String email);

  /// Emails [email] a sign-in link in CrewPoint's own words, through the
  /// `sendSignInLink` callable (Spec #233 Req 12; #241). The link returns
  /// to [returnTo]. Throws a `FirebaseFunctionsException` on failure, such
  /// as `resource-exhausted` when too many were asked for.
  Future<void> sendSignInLink({
    required String email,
    required String returnTo,
    required String language,
  });

  /// Whether [link] is an email sign-in link.
  bool isSignInLink(String link);

  /// Finishes signing in with [link] for [email].
  Future<EmailLinkOutcome> completeSignInLink({
    required String email,
    required String link,
  });

  /// Texts a code to [phone] (E.164). Firebase sends it, only to the US,
  /// Canada and the UK by the project's SMS region policy.
  Future<PhoneCodeOutcome> sendPhoneCode(String phone);

  /// Signs in with the code texted for [verificationId].
  Future<AuthResult> confirmPhoneCode({
    required String verificationId,
    required String code,
  });

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
    this.phoneNumber,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// The account's phone number in E.164. Firebase sets it only once the
  /// SMS code is entered, so it is always verified (Spec #233 Req 13).
  final String? phoneNumber;

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

/// How finishing an email sign-in link went (#241).
sealed class EmailLinkOutcome {
  const EmailLinkOutcome();
}

class EmailLinkSignedIn extends EmailLinkOutcome {
  const EmailLinkSignedIn(this.user);
  final AuthUser user;
}

/// The link was sent to another address.
class EmailLinkWrongEmail extends EmailLinkOutcome {
  const EmailLinkWrongEmail();
}

/// The link has expired or was already used.
class EmailLinkExpired extends EmailLinkOutcome {
  const EmailLinkExpired();
}

class EmailLinkFailed extends EmailLinkOutcome {
  const EmailLinkFailed(this.message);
  final String message;
}

/// How asking for a phone code went (#241).
sealed class PhoneCodeOutcome {
  const PhoneCodeOutcome();
}

class PhoneCodeSent extends PhoneCodeOutcome {
  const PhoneCodeSent(this.verificationId);
  final String verificationId;
}

/// Android sometimes reads the code itself and signs in at once.
class PhoneSignedIn extends PhoneCodeOutcome {
  const PhoneSignedIn(this.user);
  final AuthUser user;
}

class PhoneCodeFailed extends PhoneCodeOutcome {
  const PhoneCodeFailed(this.message);
  final String message;
}
