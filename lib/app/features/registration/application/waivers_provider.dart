import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/registration/data/waiver_repository.dart';
import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

final waiverRepositoryProvider = Provider<WaiverRepository>(
  (ref) => WaiverRepository(firestore: ref.watch(firestoreProvider)),
);

/// An event's waivers, live (#246), for settings and the People filter.
final eventWaiversProvider = StreamProvider.autoDispose
    .family<List<Waiver>, String>(
      (ref, eventId) => ref.watch(waiverRepositoryProvider).watch(eventId),
    );
