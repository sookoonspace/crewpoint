import 'dart:async';
import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
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
      // signInWithProvider() throws UnimplementedError on web — Firebase
      // Auth's web SDK uses popup-based OAuth instead. Mobile (iOS/Android)
      // uses the system sheet / Custom Tab via signInWithProvider.
      final result = kIsWeb
          ? await _firebaseAuth.signInWithPopup(googleProvider)
          : await _firebaseAuth.signInWithProvider(googleProvider);
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
      // See [signInWithGoogle] for the web-vs-mobile rationale.
      final result = kIsWeb
          ? await _firebaseAuth.signInWithPopup(appleProvider)
          : await _firebaseAuth.signInWithProvider(appleProvider);
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
    // A fresh ID token carries the new `email_verified`, which linking an
    // account to its registration checks on the server (Req 46).
    await _firebaseAuth.currentUser?.getIdToken(true);
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    // firebase_auth 6 removed `FirebaseAuth.fetchSignInMethodsForEmail`.
    // The removal is deliberate and there is no replacement: the call
    // reveals whether an email is registered, which is exactly what
    // Email Enumeration Protection exists to prevent. Google enables that
    // protection by default on new projects, and when it is on the API
    // already returned an empty list.
    //
    // Returning `const []` therefore preserves the behaviour this app
    // already saw under enumeration protection, and every caller is
    // written for it: `AuthNotifier.signInWithEmail` treats an empty list
    // as "never suggest" precisely so it cannot leak account existence.
    // The practical effect is that `AuthFailure.suggestedProvider` is now
    // always null, so a failed password sign-in shows the plain
    // "Incorrect email or password" message instead of routing the user
    // to an OAuth tile.
    //
    // The seam is kept rather than deleted so the contract, its tests and
    // the UI branch survive intact if Firebase ever ships an
    // enumeration-safe replacement. Removing the now-inert UX path is
    // tracked separately.
    return const [];
  }

  @override
  Future<void> sendSignInLink({
    required String email,
    required String returnTo,
    required String language,
  }) async {
    await FirebaseFunctions.instance
        .httpsCallable(
          'sendSignInLink',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call<Map<String, dynamic>>({
          'email': email,
          'returnTo': returnTo,
          'language': language,
        });
  }

  @override
  bool isSignInLink(String link) => _firebaseAuth.isSignInWithEmailLink(link);

  @override
  Future<EmailLinkOutcome> completeSignInLink({
    required String email,
    required String link,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailLink(
        email: email,
        emailLink: link,
      );
      return EmailLinkSignedIn(_mapUser(credential.user!));
    } on fb.FirebaseAuthException catch (e, st) {
      log('Email link sign-in failed', error: e, stackTrace: st, name: 'auth');
      return switch (e.code) {
        // Firebase checks the address against the one the link was made for.
        'invalid-email' => const EmailLinkWrongEmail(),
        'invalid-action-code' ||
        'expired-action-code' => const EmailLinkExpired(),
        _ => EmailLinkFailed(_mapFirebaseError(e.code)),
      };
    }
  }

  /// Web sign-ins waiting for their code, by the ID handed back.
  final Map<String, fb.ConfirmationResult> _webCodes = {};
  int _webCodeCount = 0;

  @override
  Future<PhoneCodeOutcome> sendPhoneCode(String phone) async {
    try {
      if (kIsWeb) {
        // An invisible reCAPTCHA is made for the page when none is given.
        final confirmation = await _firebaseAuth.signInWithPhoneNumber(phone);
        final id = 'web-${_webCodeCount++}';
        _webCodes[id] = confirmation;
        return PhoneCodeSent(id);
      }
      final outcome = Completer<PhoneCodeOutcome>();
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          if (outcome.isCompleted) return;
          try {
            final result = await _firebaseAuth.signInWithCredential(credential);
            outcome.complete(PhoneSignedIn(_mapUser(result.user!)));
          } on fb.FirebaseAuthException catch (e) {
            outcome.complete(PhoneCodeFailed(_mapFirebaseError(e.code)));
          }
        },
        verificationFailed: (e) {
          log('Phone code failed', error: e, name: 'auth');
          if (!outcome.isCompleted) {
            outcome.complete(PhoneCodeFailed(_mapFirebaseError(e.code)));
          }
        },
        codeSent: (verificationId, _) {
          if (!outcome.isCompleted) {
            outcome.complete(PhoneCodeSent(verificationId));
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return await outcome.future;
    } on fb.FirebaseAuthException catch (e, st) {
      log('Phone code failed', error: e, stackTrace: st, name: 'auth');
      return PhoneCodeFailed(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<AuthResult> confirmPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    try {
      final web = _webCodes[verificationId];
      final result = web != null
          ? await web.confirm(code)
          : await _firebaseAuth.signInWithCredential(
              fb.PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: code,
              ),
            );
      _webCodes.remove(verificationId);
      return AuthSuccess(_mapUser(result.user!));
    } on fb.FirebaseAuthException catch (e, st) {
      log('Phone code confirm failed', error: e, stackTrace: st, name: 'auth');
      return AuthResultFailure(_mapFirebaseError(e.code));
    }
  }

  AuthUser _mapUser(fb.User user) => AuthUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName,
    photoUrl: user.photoURL,
    emailVerified: user.emailVerified,
    providerIds: user.providerData.map((p) => p.providerId).toList(),
    phoneNumber: user.phoneNumber,
  );

  String _mapFirebaseError(String code) => firebaseAuthErrorMessage(code);
}
