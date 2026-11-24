import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/registration/domain/public_event.dart';

/// The public event page for a slug (#240), read once per visit through
/// `getEventPage`. A failure is shown at once, never retried on its own,
/// since retrying would count against the address's rate limit; Retry
/// invalidates it.
final eventPageProvider = FutureProvider.autoDispose
    .family<PublicEvent, String>(
      (ref, slug) => ref.watch(memberCallsProvider).getEventPage(slug),
      retry: (_, _) => null,
    );
