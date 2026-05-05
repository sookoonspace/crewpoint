import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';
import 'package:crewpoint_app/app/features/onboarding/application/onboarding_provider.dart';

/// Determines the primary auth provider for the current user.
enum AuthProviderType { email, google, apple, unknown }

/// Wrapper around the `deleteUserAccount` Cloud Function call.
///
/// Defaults to `FirebaseFunctions.instance.httpsCallable('deleteUserAccount')`;
/// tests inject a stub. Mirrors the `disputeSettlementCallableProvider`
/// pattern in `lib/app/core/providers.dart`.
typedef AccountDeletionCallable = Future<void> Function();

/// Handles the complete client-side account deletion flow:
/// 1. Re-authenticate user (provider-aware)
/// 2. Call deleteUserAccount Cloud Function
/// 3. Clear local data (Drift DB + secure storage)
/// 4. Sign out
class AccountDeletionService {
  AccountDeletionService({
    required AppDatabase database,
    required SecureStorageService secureStorage,
    FirebaseAuth? firebaseAuth,
    FirebaseFunctions? functions,
    AccountDeletionCallable? deletionCallable,
  }) : _database = database,
       _secureStorage = secureStorage,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _functions = functions,
       _deletionCallable = deletionCallable;

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final FirebaseAuth _firebaseAuth;
  final FirebaseFunctions? _functions;
  final AccountDeletionCallable? _deletionCallable;

  Future<void> _callDeleteUserAccount() {
    if (_deletionCallable != null) return _deletionCallable();
    final functions = _functions ?? FirebaseFunctions.instance;
    final callable = functions.httpsCallable('deleteUserAccount');
    return callable.call<Map<String, dynamic>>();
  }

  /// Returns the primary auth provider for the current user.
  AuthProviderType get currentAuthProvider {
    final user = _firebaseAuth.currentUser;
    if (user == null) return AuthProviderType.unknown;

    for (final provider in user.providerData) {
      if (provider.providerId == 'password') return AuthProviderType.email;
      if (provider.providerId == 'google.com') return AuthProviderType.google;
      if (provider.providerId == 'apple.com') return AuthProviderType.apple;
    }
    return AuthProviderType.unknown;
  }

  /// Re-authenticates with email/password.
  Future<bool> reAuthenticateWithEmail(String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user?.email == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e, st) {
      log('Email re-auth failed', error: e, stackTrace: st, name: 'deletion');
      return false;
    }
  }

  /// Re-authenticates with Google.
  ///
  /// Uses Firebase Auth's `reauthenticateWithProvider(GoogleAuthProvider)`
  /// — same path as the matching Apple method below — instead of the
  /// legacy `google_sign_in` plugin. The unified flow works on iOS,
  /// Android, and web through the same Custom Tab / SafariViewController
  /// / popup OAuth handler.
  Future<bool> reAuthenticateWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      await _firebaseAuth.currentUser?.reauthenticateWithProvider(
        googleProvider,
      );
      return true;
    } catch (e, st) {
      log('Google re-auth failed', error: e, stackTrace: st, name: 'deletion');
      return false;
    }
  }

  /// Re-authenticates with Apple.
  Future<bool> reAuthenticateWithApple() async {
    try {
      final appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      await _firebaseAuth.currentUser?.reauthenticateWithProvider(
        appleProvider,
      );
      return true;
    } catch (e, st) {
      log('Apple re-auth failed', error: e, stackTrace: st, name: 'deletion');
      return false;
    }
  }

  /// Calls the deleteUserAccount Cloud Function, then clears local data.
  ///
  /// Returns `(errorCode: null, message: null)` on success. On failure
  /// returns a typed error code matching the Cloud Function's
  /// `details.stage` payload ([_kFirestoreStageCode],
  /// [_kStorageStageCode], [_kAuthStageCode]) or one of the generic
  /// codes ([_kUnauthenticatedCode], [_kUnknownCode]) plus a
  /// user-facing message.
  ///
  /// Mirrors the `(:user, :failure)` record idiom in
  /// `lib/app/features/auth/application/auth_provider.dart` rather than
  /// introducing a new sealed-class result type.
  Future<({String? errorCode, String? message})>
  executeAccountDeletion() async {
    try {
      await _callDeleteUserAccount();

      // Local-data clear is best-effort; server-side state is the source
      // of truth. A failure here must not flip success → failure.
      try {
        await _clearLocalData();
      } catch (e, st) {
        log(
          'Local-data clear failed (non-fatal)',
          error: e,
          stackTrace: st,
          name: 'deletion',
        );
      }

      // Force the client into Unauthenticated so the global authProvider
      // redirect lands the user on /auth.
      //
      // Firebase Auth's iOS client does NOT detect server-side user
      // deletion in real time — it only notices on the next ID-token
      // refresh (~hourly). Without this explicit signOut the dialog
      // sits on step 2 forever and the user has to force-quit the app.
      // This is a CLIENT-side call (clears the local credential); it
      // does not talk to a now-deleted server-side user.
      try {
        await _firebaseAuth.signOut();
      } catch (e, st) {
        log(
          'Post-deletion signOut failed (non-fatal — server-side '
          'deletion already succeeded; auth listener will fire on '
          'next token refresh)',
          error: e,
          stackTrace: st,
          name: 'deletion',
        );
      }

      return (errorCode: null, message: null);
    } on FirebaseFunctionsException catch (e, st) {
      log(
        'Cloud Function failed: ${e.code}',
        error: e,
        stackTrace: st,
        name: 'deletion',
      );
      return _mapFunctionsException(e);
    } catch (e, st) {
      log(
        'Account deletion failed',
        error: e,
        stackTrace: st,
        name: 'deletion',
      );
      return (
        errorCode: _kUnknownCode,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Maps a [FirebaseFunctionsException] to a typed `(errorCode, message)`
  /// pair using the Cloud Function's `details.stage` field. Falls back to
  /// generic codes when the Cloud Function did not surface a stage.
  ({String? errorCode, String? message}) _mapFunctionsException(
    FirebaseFunctionsException e,
  ) {
    if (e.code == 'unauthenticated') {
      return (
        errorCode: _kUnauthenticatedCode,
        message: 'Please sign in again to delete your account.',
      );
    }
    final details = e.details;
    final stage = details is Map ? details['stage'] : null;
    return switch (stage) {
      'firestore' => (
        errorCode: _kFirestoreStageCode,
        message:
            "We couldn't delete your data. Tap Try again or contact "
            'support.',
      ),
      'storage' => (
        errorCode: _kStorageStageCode,
        // Storage failures are surfaced as warnings server-side and never
        // user-visible (Cloud Function continues past them); included
        // here for completeness so downstream callers don't have to
        // special-case the absent code.
        message:
            'A storage cleanup step failed; your data was deleted but '
            'one or more files may need manual cleanup.',
      ),
      'auth' => (
        errorCode: _kAuthStageCode,
        message:
            'Your data was deleted but we could not fully remove your '
            'account. Tap Try again — your data is gone, only the '
            'sign-in record remains.',
      ),
      _ => (
        errorCode: _kUnknownCode,
        message: e.message ?? 'Account deletion failed. Please try again.',
      ),
    };
  }

  // ----- Stage error codes returned to the dialog. ----- //
  static const String _kFirestoreStageCode = 'firestore-cleanup-failed';
  static const String _kStorageStageCode = 'storage-cleanup-failed';
  static const String _kAuthStageCode = 'auth-delete-failed';
  static const String _kUnauthenticatedCode = 'unauthenticated';
  static const String _kUnknownCode = 'unknown';

  // ----- Public re-exports for callers (dialog, tests). ----- //
  /// Returned when the Cloud Function fails during the Firestore wipe.
  static const String firestoreCleanupFailedCode = _kFirestoreStageCode;

  /// Returned when the Cloud Function emits a storage warning. Storage
  /// failures are non-fatal server-side and won't normally reach the
  /// client; this code exists so the mapping is exhaustive.
  static const String storageCleanupFailedCode = _kStorageStageCode;

  /// Returned when the Cloud Function fails to delete the Firebase Auth
  /// user (typically: retry exhaustion). Firestore + Storage are gone;
  /// only the sign-in record remains.
  static const String authDeleteFailedCode = _kAuthStageCode;

  /// Returned when the Cloud Function rejects the call as unauthenticated.
  static const String unauthenticatedCode = _kUnauthenticatedCode;

  /// Returned when no typed code is available (network error,
  /// unrecognised exception, etc.).
  static const String unknownCode = _kUnknownCode;

  /// Clears local cache: Drift tables + secure storage.
  ///
  /// Drift wipes are wrapped so a failure there does not prevent the
  /// secure-storage cleanup — the persisted secure-storage state is what
  /// gates the global router's onboarding redirect on next launch, so
  /// reaching that step matters more than the Drift wipe.
  ///
  /// `secureStorage.deleteAll()` wipes EVERY key including
  /// `onboardingCompleteKey`. We immediately re-pin it to `'true'` so the
  /// next sign-up on this device does not re-trigger onboarding. Onboarding
  /// completion is a per-device flag, not auth-scoped.
  Future<void> _clearLocalData() async {
    try {
      await _database.delete(_database.chatMessages).go();
      await _database.delete(_database.expenses).go();
      await _database.delete(_database.tasks).go();
      await _database.delete(_database.events).go();
      await _database.delete(_database.users).go();
    } catch (e, st) {
      log(
        'Drift wipe failed; continuing to secure-storage cleanup',
        error: e,
        stackTrace: st,
        name: 'deletion',
      );
    }

    await _secureStorage.deleteAll();
    await _secureStorage.write(key: onboardingCompleteKey, value: 'true');
  }
}
