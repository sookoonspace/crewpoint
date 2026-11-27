import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';

/// My registrations not confirmed yet, for home (#292). Home only adds
/// them beside "My events", so a failure (offline, say) leaves the section
/// out and is logged, rather than hiding the events home can show.
final myWaitingRegistrationsProvider =
    FutureProvider.autoDispose<List<WaitingRegistration>>((ref) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const [];
      try {
        return await ref.watch(memberCallsProvider).getMyWaitingRegistrations();
      } on Object catch (e, st) {
        log('getMyWaitingRegistrations failed', error: e, stackTrace: st);
        return const [];
      }
    }, retry: (_, _) => null);
