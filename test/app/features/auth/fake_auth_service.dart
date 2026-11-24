import 'dart:async';

import 'package:crewpoint_app/app/core/services/i_auth_service.dart';

class FakeAuthService implements IAuthService {
  AuthResult? nextResult;
  AuthUser? _currentUser;
  final _controller = StreamController<AuthUser?>.broadcast();

  /// Records every `sendEmailVerification` call so tests can assert on
  /// resend invocations.
  int sendEmailVerificationCalls = 0;

  /// When set, the next `sendEmailVerification` call throws this exception.
  Object? sendEmailVerificationError;

  /// Records every `reloadCurrentUser` call.
  int reloadCalls = 0;

  /// Stubs the response of `fetchSignInMethodsForEmail`. Defaults to an
  /// empty list (mimics email-enumeration-protection-on / no-account).
  List<String> nextSignInMethods = const [];

  /// Records every `fetchSignInMethodsForEmail` call's email arg.
  final List<String> fetchSignInMethodsCalls = [];

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = nextResult ?? const AuthResultFailure('Not configured');
    if (result is AuthSuccess) {
      _currentUser = result.user;
      _controller.add(result.user);
    }
    return result;
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final result = nextResult ?? const AuthResultFailure('Not configured');
    if (result is AuthSuccess) {
      _currentUser = result.user;
      _controller.add(result.user);
    }
    return result;
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    final result = nextResult ?? const AuthResultFailure('Not configured');
    if (result is AuthSuccess) {
      _currentUser = result.user;
      _controller.add(result.user);
    }
    return result;
  }

  @override
  Future<AuthResult> signInWithApple() async {
    final result = nextResult ?? const AuthResultFailure('Not configured');
    if (result is AuthSuccess) {
      _currentUser = result.user;
      _controller.add(result.user);
    }
    return result;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> sendEmailVerification() async {
    sendEmailVerificationCalls++;
    if (sendEmailVerificationError != null) {
      throw sendEmailVerificationError!;
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    reloadCalls++;
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    fetchSignInMethodsCalls.add(email);
    return nextSignInMethods;
  }

  /// Sign-in links asked for, as `email|returnTo|language` (#241).
  final List<String> signInLinksSent = [];

  /// When set, the next `sendSignInLink` throws this.
  Object? sendSignInLinkError;

  /// The address each link was made for: completing a link checks it, as
  /// Firebase does. A link not listed here has expired or was used.
  final Map<String, String> linkEmails = {};

  /// Phone numbers a code was asked for, and the code Firebase would text.
  final List<String> phoneCodesSent = [];
  String phoneCode = '123456';

  /// When set, the next `sendPhoneCode` returns this.
  PhoneCodeOutcome? nextPhoneOutcome;

  AuthUser _userFor({String email = '', String? phone}) => AuthUser(
    uid: 'u-${email.isEmpty ? phone : email}',
    email: email,
    emailVerified: email.isNotEmpty,
    phoneNumber: phone,
    providerIds: [if (email.isNotEmpty) 'password' else 'phone'],
  );

  @override
  Future<void> sendSignInLink({
    required String email,
    required String returnTo,
    required String language,
  }) async {
    signInLinksSent.add('$email|$returnTo|$language');
    final error = sendSignInLinkError;
    if (error != null) {
      sendSignInLinkError = null;
      throw error;
    }
  }

  @override
  bool isSignInLink(String link) {
    final uri = Uri.tryParse(link);
    return uri?.queryParameters['mode'] == 'signIn' &&
        (uri?.queryParameters['oobCode']?.isNotEmpty ?? false);
  }

  @override
  Future<EmailLinkOutcome> completeSignInLink({
    required String email,
    required String link,
  }) async {
    final code = Uri.parse(link).queryParameters['oobCode'];
    final expected = linkEmails[code];
    if (expected == null) return const EmailLinkExpired();
    if (expected != email.trim().toLowerCase()) {
      return const EmailLinkWrongEmail();
    }
    linkEmails.remove(code);
    final user = _userFor(email: expected);
    setCurrentUser(user);
    return EmailLinkSignedIn(user);
  }

  @override
  Future<PhoneCodeOutcome> sendPhoneCode(String phone) async {
    phoneCodesSent.add(phone);
    final next = nextPhoneOutcome;
    nextPhoneOutcome = null;
    return next ?? PhoneCodeSent('verify:$phone');
  }

  @override
  Future<AuthResult> confirmPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    if (code != phoneCode) {
      return const AuthResultFailure(
        "That code isn't right. Check it and try again.",
      );
    }
    final user = _userFor(phone: verificationId.replaceFirst('verify:', ''));
    setCurrentUser(user);
    return AuthSuccess(user);
  }

  /// Test setter — drives state transitions in tests where the
  /// ordinary sign-in/up paths aren't exercised. Updates [currentUser]
  /// AND broadcasts on `authStateChanges`.
  void setCurrentUser(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  void dispose() {
    _controller.close();
  }
}
