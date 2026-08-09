import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/firebase_service.dart';

/// Guards the Pillar 1 offline contract at the only point it is declared.
///
/// The real behaviour (IndexedDB hydration on web cold start) can only be
/// observed in a browser, so these assertions lock the *configuration*
/// instead: if someone drops the flag or pins an unbounded cache, the suite
/// fails here rather than in a tester's browser weeks later.
void main() {
  group('FirebaseService.firestoreSettings', () {
    test('enables offline persistence', () {
      expect(FirebaseService.firestoreSettings.persistenceEnabled, isTrue);
    });

    test('leaves cacheSizeBytes at the SDK default', () {
      // Unset => 40 MB LRU. CACHE_SIZE_UNLIMITED would let IndexedDB grow
      // without a ceiling on web.
      expect(FirebaseService.firestoreSettings.cacheSizeBytes, isNull);
      expect(
        FirebaseService.firestoreSettings.cacheSizeBytes,
        isNot(Settings.CACHE_SIZE_UNLIMITED),
      );
    });

    test('does not pin host or ssl', () {
      // Pinning either here would silently defeat a later
      // `useFirestoreEmulator` call.
      expect(FirebaseService.firestoreSettings.host, isNull);
      expect(FirebaseService.firestoreSettings.sslEnabled, isNull);
    });
  });
}
