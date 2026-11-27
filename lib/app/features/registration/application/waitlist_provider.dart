import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/registration/domain/waitlist.dart';

/// The waitlist for an event (#248), through `getWaitlist`; invalidated
/// after each action, and by Retry.
final waitlistProvider = FutureProvider.autoDispose.family<WaitlistView, String>(
  (ref, eventId) => ref.watch(memberCallsProvider).getWaitlist(eventId),
  retry: (_, _) => null,
);
