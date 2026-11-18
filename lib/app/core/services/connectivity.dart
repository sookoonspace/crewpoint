import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Whether the app can reach the server right now. Saves that must not be
/// queued offline ask first (Spec #186 Req 34, ledger L10).
abstract interface class IConnectivity {
  Future<bool> isOnline();
}

/// Asks the server itself for the public `config/app` document, so it
/// answers for Firestore on every platform, web included, with no extra
/// plugin. Anything but an answer within [timeout] counts as offline.
class FirestoreConnectivity implements IConnectivity {
  FirestoreConnectivity(
    this._firestore, {
    this.timeout = const Duration(seconds: 5),
  });

  final FirebaseFirestore _firestore;
  final Duration timeout;

  @override
  Future<bool> isOnline() async {
    try {
      await _firestore
          .doc('config/app')
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    } on FirebaseException {
      return false;
    }
  }
}
