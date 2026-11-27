import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';

/// My registrations not confirmed yet, for home (#292). Home only adds
/// them beside "My events", so a failure (offline, say) leaves the section
/// out and is logged, rather than hiding the events home can show. Read
/// again whenever the app comes back to the foreground, so an offer made
/// meanwhile shows; home also offers pull to refresh.
final myWaitingRegistrationsProvider =
    FutureProvider.autoDispose<List<WaitingRegistration>>((ref) async {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return const [];
      final resumed = ref
          .watch(appLifecycleSourceProvider)
          .stream
          .where((s) => s == AppLifecycleState.resumed)
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(resumed.cancel);
      try {
        return await ref.watch(memberCallsProvider).getMyWaitingRegistrations();
      } on Object catch (e, st) {
        log('getMyWaitingRegistrations failed', error: e, stackTrace: st);
        return const [];
      }
    }, retry: (_, _) => null);
