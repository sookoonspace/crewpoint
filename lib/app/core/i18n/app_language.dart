import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';

/// The languages screens and emails come in (Spec #233 Req 55, 56).
enum AppLanguage {
  en('en'),
  gu('gu');

  const AppLanguage(this.code);

  /// Stored on the device and on `users/{uid}.language`, which the server
  /// reads for emails.
  final String code;

  Locale get locale => Locale(code);

  static AppLanguage? fromCode(Object? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// Where a signed-in person's language is kept: `users/{uid}.language`.
abstract interface class ILanguageAccountStore {
  Future<AppLanguage?> read(String uid);
  Future<void> save(String uid, AppLanguage language);
}

class FirestoreLanguageAccountStore implements ILanguageAccountStore {
  FirestoreLanguageAccountStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<AppLanguage?> read(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return AppLanguage.fromCode(snap.data()?['language']);
  }

  @override
  Future<void> save(String uid, AppLanguage language) => _firestore
      .collection('users')
      .doc(uid)
      .set({'language': language.code}, SetOptions(merge: true));
}

/// Device key for the chosen language. Versioned, like the theme's.
const languageStorageKey = 'language_v1';

/// The app's language. Chosen before sign-in, it is kept on the device;
/// once signed in it is also saved to the account so emails use it, and an
/// account's saved language is adopted on a device that has none (Req 56).
class AppLanguageNotifier extends Notifier<AppLanguage> {
  String? _uid;

  @override
  AppLanguage build() =>
      AppLanguage.fromCode(_prefs()?.getString(languageStorageKey)) ??
      AppLanguage.en;

  /// Whether this device holds a choice the person made.
  bool get chosenOnDevice => _prefs()?.getString(languageStorageKey) != null;

  /// Sets the language, keeps it on the device, and saves it to the
  /// signed-in account.
  void set(AppLanguage language) {
    state = language;
    final prefs = _prefs();
    if (prefs != null) {
      unawaited(
        prefs
            .setString(languageStorageKey, language.code)
            .catchError((Object e, StackTrace st) => _log('keep', e, st)),
      );
    }
    final uid = _uid;
    if (uid != null) unawaited(_saveToAccount(uid, language));
  }

  /// Called when someone signs in (null when they sign out). A choice made
  /// on this device is saved to the account; otherwise the account's saved
  /// language, if any, is used here too.
  Future<void> accountChanged(String? uid) async {
    _uid = uid;
    if (uid == null) return;
    final store = ref.read(languageAccountStoreProvider);
    try {
      if (chosenOnDevice) {
        await store.save(uid, state);
      } else {
        final saved = await store.read(uid);
        if (saved != null && _uid == uid) set(saved);
      }
    } catch (e, st) {
      _log('sync with the account', e, st);
    }
  }

  Future<void> _saveToAccount(String uid, AppLanguage language) async {
    try {
      await ref.read(languageAccountStoreProvider).save(uid, language);
    } catch (e, st) {
      _log('save to the account', e, st);
    }
  }

  SharedPreferences? _prefs() {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      // Widget tests that don't override preferences keep English.
      return null;
    }
  }

  bool _log(String what, Object error, StackTrace stack) {
    developer.log(
      'Failed to $what the language',
      name: 'language',
      error: error,
      stackTrace: stack,
    );
    return false;
  }
}

/// The account store, over the app's Firestore. Tests override it.
final languageAccountStoreProvider = Provider<ILanguageAccountStore>(
  (ref) => FirestoreLanguageAccountStore(ref.watch(firestoreProvider)),
);

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);
