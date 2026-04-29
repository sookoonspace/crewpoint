import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/auth/data/firebase_auth_error_messages.dart';

/// Firebase implementation of [IAuthService].
class FirebaseAuthService implements IAuthService {
  FirebaseAuthService({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

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
      return AuthSuccess(_mapUser(credential.user!));
    } on fb.FirebaseAuthException catch (e, st) {
      log('Email sign-up failed', error: e, stackTrace: st, name: 'auth');
      return AuthResultFailure(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResultFailure('Google sign-in cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
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
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  @override
  Future<void> deleteAccount() async {
    await _firebaseAuth.currentUser?.delete();
  }

  AuthUser _mapUser(fb.User user) => AuthUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );

  String _mapFirebaseError(String code) => firebaseAuthErrorMessage(code);
}
