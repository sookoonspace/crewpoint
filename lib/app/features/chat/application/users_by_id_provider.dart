import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

/// Everyone with a profile in an event, by uid, live: names, photos and
/// payment handles from `events/{eventId}/profiles` (Req 37). People who
/// left keep their name there, so older messages, tasks and expenses still
/// show who it was.
final eventProfilesProvider =
    StreamProvider.family<Map<String, AppUser>, String>(
      (ref, eventId) =>
          ref.watch(userRepositoryProvider).watchEventProfiles(eventId),
    );

/// Display info for the people in an event, keyed by uid. The family key is
/// the event ID.
///
/// Other people come only from the event's profiles, because `users/{uid}`
/// is readable only by its owner (Req 37). The signed-in person falls back
/// to their own document until the server has copied their profile, just
/// after creating or joining an event.
final usersByIdProvider = FutureProvider.family<Map<String, AppUser>, String>((
  ref,
  eventId,
) async {
  final people = await ref.watch(eventProfilesProvider(eventId).future);
  final me = ref.watch(currentUserIdProvider);
  if (me == null || people.containsKey(me)) return people;
  final self = await ref.watch(userRepositoryProvider).getUser(me);
  return {...people, me: ?self};
});
