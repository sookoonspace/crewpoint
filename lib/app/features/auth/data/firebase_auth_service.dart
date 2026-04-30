import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/data/firebase_auth_error_messages.dart';

/// Firebase implementation of [IAuthService].
class FirebaseAuthService implements IAuthService {
  FirebaseAuthService({fb.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _firebaseAuth;

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? _mapUser(user) : null;
  }

  @override
  Stream<AuthUser?> get authStateChanges => _firebaseAuth
      .authStateChanges()
      .map((user) => user != null ? _mapUser(user) : null);

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthSuccess(_mapUser(credential.user!));
    } on fb.FirebaseAuthException catch (e, st) {
      log('Email sign-in failed', error: e, stackTrace: st, name: 'auth');
      return AuthResultFailure(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.updateDisplayName(displayName);
      // Fire-and-forget the verification email. Failure here (rate limit,
      // template misconfig) shouldn't block the signup itself; the user
      // can resend from the unverified-email banner if it didn't arrive.
      try {
        await credential.user!.sendEmailVerification();
      } catch (e, st) {
        log(
          'Verification email send failed at signup',
          error: e,
          stackTrace: st,
          name: 'auth',
        );
      }
      return AuthSuccess(_mapUser(credential.user!));
    } on fb.FirebaseAuthException catch (e, st) {
      log('Email sign-up failed', error: e, stackTrace: st, name: 'auth');
      return AuthResultFailure(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleProvider = fb.GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final result = await _firebaseAuth.signInWithProvider(googleProvider);
      return AuthSuccess(_mapUser(result.user!));
    } on fb.FirebaseAuthException catch (e, st) {
      log('Google sign-in failed', error: e, stackTrace: st, name: 'auth');
      return AuthResultFailure(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<AuthResult> signInWithApple() async {
    try {
      final appleProvider = fb.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final result = await _firebaseAuth.signInWithProvider(appleProvider);
      return AuthSuccess(_mapUser(result.user!));
    } on fb.FirebaseAuthException catch (e, st) {
      log('Apple sign-in failed', error: e, stackTrace: st, name: 'auth');
      return AuthResultFailure(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    await _firebaseAuth.currentUser?.delete();
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e, st) {
      log(
        'sendEmailVerification failed (${e.code})',
        error: e,
        stackTrace: st,
        name: 'auth',
      );
      // Re-throw with a friendly message so AuthNotifier can surface it.
      throw Exception(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    try {
      // ignore: deprecated_member_use
      return await _firebaseAuth.fetchSignInMethodsForEmail(email);
    } catch (e, st) {
      log(
        'fetchSignInMethodsForEmail failed (returning [])',
        error: e,
        stackTrace: st,
        name: 'auth',
      );
      return const [];
    }
  }

  AuthUser _mapUser(fb.User user) => AuthUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName,
    photoUrl: user.photoURL,
    emailVerified: user.emailVerified,
    providerIds: user.providerData.map((p) => p.providerId).toList(),
  );

  String _mapFirebaseError(String code) => firebaseAuthErrorMessage(code);
}
