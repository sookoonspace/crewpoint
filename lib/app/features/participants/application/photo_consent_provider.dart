import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/photo_consent.dart';

/// The photo consent list, live (#247), or null before the server has
/// built it. Gate it on `photoConsent.read` at the caller: rules refuse
/// anyone else.
final photoConsentListProvider = StreamProvider.autoDispose
    .family<PhotoConsentList?, String>(
      (ref, eventId) => ref
          .watch(firestoreProvider)
          .doc('events/$eventId/photoConsent/current')
          .snapshots()
          .map((doc) {
            final data = doc.data();
            return data == null ? null : PhotoConsentList.fromFirestore(data);
          }),
    );
