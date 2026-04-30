import 'dart:developer';

import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/auth_failure.dart';
import 'package:crewpoint_app/app/features/auth/domain/repositories/i_auth_repository.dart';

/// Repository wrapping [IAuthService] with typed error handling.
class AuthRepository implements IAuthRepository {
  const AuthRepository({required IAuthService authService})
    : _authService = authService;

  final IAuthService _authService;

  AppUser _toAppUser(AuthUser user) => AppUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoUrl,
    emailVerified: user.emailVerified,
    providerIds: user.providerIds,
  );

  @override
  Stream<AppUser?> get authStateChanges => _authService.authStateChanges.map(
    (u) => u == null ? null : _toAppUser(u),
  );

  @override
  AppUser? get currentUser {
    final user = _authService.currentUser;
    if (user == null) return null;
    return _toAppUser(user);
  }

  @override
  Future<({AppUser? user, AuthFailure? failure})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      return switch (result) {
        AuthSuccess(:final user) => (user: _toAppUser(user), failure: null),
        AuthResultFailure(:final message) => (
          user: null,
          failure: AuthFailure(type: AuthFailureType.unknown, message: message),
        ),
      };
    } catch (e, st) {
      log('signInWithEmail failed', error: e, stackTrace: st, name: 'auth');
      return (
        user: null,
        failure: const AuthFailure(
          type: AuthFailureType.unknown,
          message: 'An unexpected error occurred.',
        ),
      );
    }
  }

  @override
  Future<({AppUser? user, AuthFailure? failure})> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final result = await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return switch (result) {
        AuthSuccess(:final user) => (user: _toAppUser(user), failure: null),
        AuthResultFailure(:final message) => (
          user: null,
          failure: AuthFailure(type: AuthFailureType.unknown, message: message),
        ),
      };
    } catch (e, st) {
      log('signUpWithEmail failed', error: e, stackTrace: st, name: 'auth');
      return (
        user: null,
        failure: const AuthFailure(
          type: AuthFailureType.unknown,
          message: 'An unexpected error occurred.',
        ),
      );
    }
  }

  @override
  Future<({AppUser? user, AuthFailure? failure})> signInWithGoogle() async {
    try {
      final result = await _authService.signInWithGoogle();
      return switch (result) {
        AuthSuccess(:final user) => (user: _toAppUser(user), failure: null),
        AuthResultFailure(:final message) => (
          user: null,
          failure: AuthFailure(type: AuthFailureType.unknown, message: message),
        ),
      };
    } catch (e, st) {
      log('signInWithGoogle failed', error: e, stackTrace: st, name: 'auth');
      return (
        user: null,
        failure: const AuthFailure(
          type: AuthFailureType.unknown,
          message: 'An unexpected error occurred.',
        ),
      );
    }
  }

  @override
  Future<({AppUser? user, AuthFailure? failure})> signInWithApple() async {
    try {
      final result = await _authService.signInWithApple();
      return switch (result) {
        AuthSuccess(:final user) => (user: _toAppUser(user), failure: null),
        AuthResultFailure(:final message) => (
          user: null,
          failure: AuthFailure(type: AuthFailureType.unknown, message: message),
        ),
      };
    } catch (e, st) {
      log('signInWithApple failed', error: e, stackTrace: st, name: 'auth');
      return (
        user: null,
        failure: const AuthFailure(
          type: AuthFailureType.unknown,
          message: 'An unexpected error occurred.',
        ),
      );
    }
  }

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<void> deleteAccount() => _authService.deleteAccount();

  @override
  Future<void> sendEmailVerification() => _authService.sendEmailVerification();

  @override
  Future<AppUser?> reloadCurrentUser() async {
    await _authService.reloadCurrentUser();
    return currentUser;
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) =>
      _authService.fetchSignInMethodsForEmail(email);
}
