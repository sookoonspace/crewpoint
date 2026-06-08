import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// Firestore implementation of [IUserRepository].
///
/// **Schema layout (post Fix 1.B Option A — projection-split):**
///
///   `users/{uid}` (publicly readable to every authenticated user):
///     displayName, photoUrl, paymentMethod, paymentHandle,
///     venmoHandle, cashappHandle, currency
///
///   `users/{uid}/private/profile` (self-only):
///     email, providerIds, fcmTokens, preferences, createdAt, updatedAt
///
/// `getUser()` reads the public doc unconditionally and *attempts* to
/// read the private subdoc. For self-reads the private read succeeds
/// and the returned [AppUser] carries `email`, `fcmTokens`, etc. For
/// non-self reads the private read is denied by the rules; the catch
/// silently returns the public-only [AppUser]. This keeps the existing
/// `usersByIdProvider` co-member-display path working unchanged while
/// the rules enforce that PII never leaks.
class FirestoreUserRepository implements IUserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  DocumentReference<Map<String, dynamic>> _privateProfileRef(String uid) =>
      _usersRef.doc(uid).collection('private').doc('profile');

  @override
  Future<AppUser?> getUser(String uid) async {
    try {
      final publicDoc = await _usersRef.doc(uid).get();
      if (!publicDoc.exists) {
        log(
          'getUser($uid): public users/$uid doc does not exist',
          name: 'profile',
        );
        return null;
      }
      final publicData = publicDoc.data()!;

      // Attempt to read the private subdoc. For self-reads this
      // succeeds and populates email + fcmTokens. For non-self reads
      // the rules deny it; we catch permission-denied and return the
      // public-only projection. Any other error is logged + rethrown.
      Map<String, dynamic>? privateData;
      try {
        final privateDoc = await _privateProfileRef(uid).get();
        if (privateDoc.exists) privateData = privateDoc.data();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }

      // Email lookup order: private subdoc (canonical) → public doc
      // (legacy / manually-edited entries). The public field isn't
      // written by `saveProfile` or `createUserIfNotExists`, but if it
      // exists it's still useful as a non-PII display fallback.
      final email =
          (privateData?['email'] as String?) ??
          (publicData['email'] as String?) ??
          '';

      final displayName = publicData['displayName'] as String?;
      if ((displayName == null || displayName.isEmpty) && email.isEmpty) {
        log(
          'getUser($uid): no displayName and no email — UI will show '
          '"Unknown member". Public doc keys: ${publicData.keys.toList()}',
          name: 'profile',
        );
      }

      return AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: publicData['photoUrl'] as String?,
        paymentMethod: publicData['paymentMethod'] as String?,
        paymentHandle: publicData['paymentHandle'] as String?,
        venmoHandle: publicData['venmoHandle'] as String?,
        cashappHandle: publicData['cashappHandle'] as String?,
        currency: publicData['currency'] as String? ?? 'USD',
      );
    } catch (e, st) {
      log('Failed to get user $uid', error: e, stackTrace: st, name: 'profile');
      return null;
    }
  }

  @override
  Future<void> saveProfile({
    required String uid,
    required String displayName,
    String? photoUrl,
    String? paymentMethod,
    String? paymentHandle,
    String? venmoHandle,
    String? cashappHandle,
  }) async {
    try {
      final batch = _firestore.batch();

      // Public projection — display + payment fields.
      final publicData = <String, dynamic>{
        'displayName': displayName,
        'paymentMethod': paymentMethod,
        'paymentHandle': paymentHandle,
        'venmoHandle': venmoHandle,
        'cashappHandle': cashappHandle,
      };
      if (photoUrl != null) {
        publicData['photoUrl'] = photoUrl;
      }
      batch.set(_usersRef.doc(uid), publicData, SetOptions(merge: true));

      // Private subdoc — only updatedAt is touched on a profile save.
      batch.set(_privateProfileRef(uid), {
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e, st) {
      log(
        'Failed to save profile for $uid',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
      rethrow;
    }
  }

  @override
  Future<void> addFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    try {
      await _privateProfileRef(uid).set({
        'fcmTokens': FieldValue.arrayUnion([
          {'value': token, 'platform': platform},
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      log(
        'Failed to add FCM token for $uid',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
    }
  }

  @override
  Future<void> removeFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    try {
      await _privateProfileRef(uid).set({
        'fcmTokens': FieldValue.arrayRemove([
          {'value': token, 'platform': platform},
        ]),
      }, SetOptions(merge: true));
    } catch (e, st) {
      log(
        'Failed to remove FCM token for $uid',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
    }
  }

  @override
  Future<NotificationPrefs> getNotificationPrefs(String uid) async {
    try {
      final snap = await _privateProfileRef(uid).get();
      final raw = snap.data()?['notificationPrefs'] as Map<String, dynamic>?;
      return NotificationPrefs.fromMap(raw);
    } on FirebaseException catch (e, st) {
      // Permission-denied on non-self reads is expected at security-rule
      // level — return defaults so the UI / FCM gate doesn't crash.
      if (e.code == 'permission-denied') {
        return const NotificationPrefs();
      }
      log(
        'Failed to read notificationPrefs for $uid',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
      return const NotificationPrefs();
    }
  }

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required NotificationPrefs prefs,
  }) async {
    try {
      await _privateProfileRef(uid).set({
        'notificationPrefs': prefs.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      log(
        'Failed to update notificationPrefs for $uid',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
      rethrow;
    }
  }

  @override
  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    List<String> providerIds = const [],
  }) async {
    try {
      final publicDoc = await _usersRef.doc(uid).get();
      if (publicDoc.exists) return;

      final batch = _firestore.batch();

      // Public projection — displayName + photoUrl (when provided).
      final publicData = <String, dynamic>{'displayName': displayName};
      if (photoUrl != null) {
        publicData['photoUrl'] = photoUrl;
      }
      batch.set(_usersRef.doc(uid), publicData);

      // Private subdoc — email, providerIds, preferences, timestamps.
      batch.set(_privateProfileRef(uid), {
        'email': email,
        'providerIds': providerIds,
        'preferences': {'dataOptIn': false, 'currency': 'USD'},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e, st) {
      log(
        'Failed to create user doc for $uid',
        error: e,
        stackTrace: st,
        name: 'profile',
      );
    }
  }
}
