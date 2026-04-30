import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/auth_failure.dart';

/// Auth state for the app.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final AppUser user;
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.failure);
  final AuthFailure failure;
}

/// Notifier managing auth state transitions.
class AuthNotifier extends Notifier<AuthState> {
  AuthNotifier({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _subscription;

  @override
  AuthState build() {
    _subscription?.cancel();
    _subscription = _authRepository.authStateChanges.listen((user) {
      if (user != null) {
        state = Authenticated(user);
      } else {
        state = const Unauthenticated();
      }
    });

    ref.onDispose(() => _subscription?.cancel());

    final currentUser = _authRepository.currentUser;
    if (currentUser != null) {
      return Authenticated(currentUser);
    }
    return const Unauthenticated();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    final (:user, :failure) = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
    if (failure != null) {
      // On password failure, best-effort look up which providers Firebase
      // recognises for this email. If only OAuth providers come back
      // (`password` absent), the account was upgraded by an OAuth merge —
      // surface a suggestion so the UI can route the user to the right
      // tile instead of a blunt "Incorrect password" message.
      // Empty list → enumeration protection on / no account → never
      // suggest (would leak account existence).
      final methods = await _authRepository.fetchSignInMethodsForEmail(email);
      final hasPassword = methods.contains('password');
      final firstOauth = methods.firstWhere(
        (m) => m != 'password',
        orElse: () => '',
      );
      final suggested = (!hasPassword && firstOauth.isNotEmpty)
          ? firstOauth
          : null;
      state = AuthError(
        AuthFailure(
          type: failure.type,
          message: failure.message,
          suggestedProvider: suggested,
        ),
      );
    } else if (user != null) {
      state = Authenticated(user);
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthLoading();
    final (:user, :failure) = await _authRepository.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (failure != null) {
      state = AuthError(failure);
    } else if (user != null) {
      state = Authenticated(user);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    final (:user, :failure) = await _authRepository.signInWithGoogle();
    if (failure != null) {
      state = AuthError(failure);
    } else if (user != null) {
      state = Authenticated(user);
    }
  }

  Future<void> signInWithApple() async {
    state = const AuthLoading();
    final (:user, :failure) = await _authRepository.signInWithApple();
    if (failure != null) {
      state = AuthError(failure);
    } else if (user != null) {
      state = Authenticated(user);
    }
  }

  /// Manually refreshes the user data in state.
  /// Use after profile edits since authStateChanges doesn't fire on profile updates.
  void refreshUser(AppUser updatedUser) {
    state = Authenticated(updatedUser);
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const Unauthenticated();
  }

  /// Resends the verification email to the currently signed-in user.
  /// Surfaces failure as an [AuthError] (rate-limited messages, etc.)
  /// so the banner UI can display them; never flips the user out of
  /// `Authenticated` on failure.
  Future<void> resendVerificationEmail() async {
    final current = state;
    if (current is! Authenticated) return;
    try {
      await _authRepository.sendEmailVerification();
    } catch (e, st) {
      log(
        'resendVerificationEmail failed',
        error: e,
        stackTrace: st,
        name: 'auth',
      );
      state = AuthError(
        AuthFailure(
          type: AuthFailureType.unknown,
          message: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
      // Restore Authenticated so the user isn't kicked out of the app.
      state = current;
    }
  }

  /// Refreshes `emailVerified` (and other server-side fields) from
  /// Firebase. Updates [Authenticated] state in place when the user
  /// is signed in.
  Future<void> reloadCurrentUser() async {
    final current = state;
    if (current is! Authenticated) return;
    final refreshed = await _authRepository.reloadCurrentUser();
    if (refreshed != null) {
      state = Authenticated(refreshed);
    }
  }
}
