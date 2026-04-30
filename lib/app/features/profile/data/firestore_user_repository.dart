import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
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
      if (!publicDoc.exists) return null;
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

      return AppUser(
        uid: uid,
        email: privateData?['email'] as String? ?? '',
        displayName: publicData['displayName'] as String?,
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
  Future<void> addFcmToken({required String uid, required String token}) async {
    try {
      await _privateProfileRef(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
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
  }) async {
    try {
      await _privateProfileRef(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
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
  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    try {
      final publicDoc = await _usersRef.doc(uid).get();
      if (publicDoc.exists) return;

      final batch = _firestore.batch();

      // Public projection — only displayName.
      batch.set(_usersRef.doc(uid), {'displayName': displayName});

      // Private subdoc — email, preferences, timestamps.
      batch.set(_privateProfileRef(uid), {
        'email': email,
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
