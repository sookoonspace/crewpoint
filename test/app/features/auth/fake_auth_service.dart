import 'dart:async';

import 'package:crewpoint_app/app/core/services/i_auth_service.dart';

class FakeAuthService implements IAuthService {
  AuthResult? nextResult;
  AuthUser? _currentUser;
  final _controller = StreamController<AuthUser?>.broadcast();

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

  void dispose() {
    _controller.close();
  }
}
