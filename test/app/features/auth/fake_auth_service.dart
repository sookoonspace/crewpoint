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
