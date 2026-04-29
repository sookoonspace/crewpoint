import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';

/// Determines the primary auth provider for the current user.
enum AuthProviderType { email, google, apple, unknown }

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
  }) : _database = database,
       _secureStorage = secureStorage,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final AppDatabase _database;
  final SecureStorageService _secureStorage;
  final FirebaseAuth _firebaseAuth;
  final FirebaseFunctions _functions;

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
  /// Returns null on success, or an error message on failure.
  Future<String?> executeAccountDeletion() async {
    try {
      // Call Cloud Function
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call<Map<String, dynamic>>();

      // Clear local data
      await _clearLocalData();

      return null; // success
    } on FirebaseFunctionsException catch (e, st) {
      log(
        'Cloud Function failed: ${e.code}',
        error: e,
        stackTrace: st,
        name: 'deletion',
      );
      return e.message ?? 'Account deletion failed. Please try again.';
    } catch (e, st) {
      log(
        'Account deletion failed',
        error: e,
        stackTrace: st,
        name: 'deletion',
      );
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Clears all local data: Drift DB tables + secure storage.
  Future<void> _clearLocalData() async {
    // Delete all Drift tables
    await _database.delete(_database.chatMessages).go();
    await _database.delete(_database.expenses).go();
    await _database.delete(_database.tasks).go();
    await _database.delete(_database.events).go();
    await _database.delete(_database.users).go();

    // Clear secure storage
    await _secureStorage.deleteAll();
  }
}
