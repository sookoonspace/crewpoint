import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// One person's profile in an event, live: name, photo and payment handles
/// from `events/{eventId}/profiles/{uid}` (Req 37). Null when they have none.
final eventProfileProvider = StreamProvider.autoDispose
    .family<AppUser?, ({String eventId, String uid})>(
      (ref, key) => ref
          .watch(userRepositoryProvider)
          .watchEventProfile(key.eventId, key.uid),
    );

/// Which people's names a screen needs in one event: the uids it shows, such
/// as message senders, assignees or payers. Order and repeats don't matter.
@immutable
class PeopleKey {
  PeopleKey(this.eventId, Iterable<String> uids)
    : uids = List.unmodifiable(uids.toSet().toList()..sort());

  final String eventId;
  final List<String> uids;

  @override
  bool operator ==(Object other) =>
      other is PeopleKey &&
      other.eventId == eventId &&
      listEquals(other.uids, uids);

  @override
  int get hashCode => Object.hash(eventId, Object.hashAll(uids));
}

/// Display info for the people a screen shows, keyed by uid, live (Req 43a).
/// Each person is read on their own, so a large event never loads everyone.
///
/// Other people come only from the event's profiles, because `users/{uid}`
/// is readable only by its owner (Req 37). The signed-in person falls back
/// to their own document until the server has copied their profile, just
/// after creating or joining an event. Someone with no profile is left out.
final peopleByIdProvider = FutureProvider.autoDispose
    .family<Map<String, AppUser>, PeopleKey>((ref, key) async {
      final me = ref.watch(currentUserIdProvider);
      final found = await Future.wait([
        for (final uid in key.uids)
          ref
              .watch(
                eventProfileProvider((eventId: key.eventId, uid: uid)).future,
              )
              .then<AppUser?>((p) => p, onError: (Object _) => null),
      ]);
      final people = <String, AppUser>{
        for (final person in found) ?person?.uid: ?person,
      };
      if (me != null && key.uids.contains(me) && !people.containsKey(me)) {
        final self = await ref.watch(userRepositoryProvider).getUser(me);
        if (self != null) people[me] = self;
      }
      return people;
    });

/// [uids]' profiles in an event, read once, for a one-off such as a
/// confirmation. Anyone who can't be read is left out.
Future<Map<String, AppUser>> fetchPeople(
  IUserRepository repo,
  String eventId,
  Iterable<String> uids,
) async {
  final found = await Future.wait([
    for (final uid in uids.toSet())
      repo
          .watchEventProfile(eventId, uid)
          .first
          .then<AppUser?>((p) => p, onError: (Object _) => null),
  ]);
  return {for (final person in found) ?person?.uid: ?person};
}
