import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/auth_failure.dart';
import 'package:crewpoint_app/app/features/auth/domain/repositories/i_auth_repository.dart';

/// Builds a debug-friendly message exposing the underlying Firebase auth
/// error code in the UI. `dart:developer.log` is silenced in Flutter web
/// release builds, so we also `debugPrint` to ensure the trace reaches
/// browser DevTools.
String _diagnosticMessage(String operation, Object error, StackTrace st) {
  log('$operation failed', error: error, stackTrace: st, name: 'auth');
  debugPrint('[auth] $operation failed: $error');
  if (error is FirebaseAuthException) {
    return 'Sign-in failed (${error.code})${error.message == null ? '' : ': ${error.message}'}';
  }
  return 'Sign-in failed: $error';
}

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
      return (
        user: null,
        failure: AuthFailure(
          type: AuthFailureType.unknown,
          message: _diagnosticMessage('signInWithEmail', e, st),
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
      return (
        user: null,
        failure: AuthFailure(
          type: AuthFailureType.unknown,
          message: _diagnosticMessage('signUpWithEmail', e, st),
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
      return (
        user: null,
        failure: AuthFailure(
          type: AuthFailureType.unknown,
          message: _diagnosticMessage('signInWithGoogle', e, st),
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
      return (
        user: null,
        failure: AuthFailure(
          type: AuthFailureType.unknown,
          message: _diagnosticMessage('signInWithApple', e, st),
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
