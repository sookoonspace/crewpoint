import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// Firestore implementation of [IUserRepository].
class FirestoreUserRepository implements IUserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  @override
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return AppUser(
        uid: uid,
        email: data['email'] as String? ?? '',
        displayName: data['displayName'] as String?,
        photoUrl: data['photoUrl'] as String?,
        paymentMethod: data['paymentMethod'] as String?,
        paymentHandle: data['paymentHandle'] as String?,
        venmoHandle: data['venmoHandle'] as String?,
        cashappHandle: data['cashappHandle'] as String?,
        currency: data['currency'] as String? ?? 'USD',
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
      final data = <String, dynamic>{
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
        'paymentMethod': paymentMethod,
        'paymentHandle': paymentHandle,
        'venmoHandle': venmoHandle,
        'cashappHandle': cashappHandle,
      };
      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }

      await _usersRef.doc(uid).set(data, SetOptions(merge: true));
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
      await _usersRef.doc(uid).set({
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
      await _usersRef.doc(uid).set({
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
      final doc = await _usersRef.doc(uid).get();
      if (doc.exists) return;

      await _usersRef.doc(uid).set({
        'email': email,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'preferences': {'dataOptIn': false, 'currency': 'USD'},
      });
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
