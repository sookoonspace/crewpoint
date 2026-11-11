import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/profile/data/firestore_user_repository.dart';

/// Req 37: other people's names and payment handles come from the event's
/// profiles, because `users/{uid}` is readable only by its owner. Req 43a:
/// only the people a screen shows are read, never the whole event.
void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(
          FirestoreUserRepository(firestore: firestore),
        ),
        currentUserIdProvider.overrideWithValue('me'),
      ],
    );
    addTearDown(container.dispose);
  });

  CollectionReference<Map<String, dynamic>> profiles(String eventId) =>
      firestore.collection('events').doc(eventId).collection('profiles');

  Future<Map<String, String?>> names(String eventId, List<String> uids) async {
    final key = PeopleKey(eventId, uids);
    final sub = container.listen(peopleByIdProvider(key), (_, _) {});
    addTearDown(sub.close);
    final people = await container.read(peopleByIdProvider(key).future);
    return {for (final e in people.entries) e.key: e.value.displayName};
  }

  test('only the people asked for, including people who left', () async {
    await profiles(
      'e1',
    ).doc('pat').set({'displayName': 'Pat', 'venmoHandle': 'pat'});
    await profiles('e1').doc('gil').set({'displayName': 'Gil'});
    await profiles('e1').doc('ann').set({'displayName': 'Ann'});
    await profiles('e2').doc('zed').set({'displayName': 'Zed'});

    expect(await names('e1', ['pat', 'gil', 'zed']), {
      'pat': 'Pat',
      'gil': 'Gil',
    });
  });

  test('the same people in any order, repeated, are one key', () {
    expect(
      PeopleKey('e1', const ['b', 'a', 'b']),
      PeopleKey('e1', const ['a', 'b']),
    );
    expect(
      PeopleKey('e1', const ['a']).hashCode,
      PeopleKey('e1', const ['a', 'a']).hashCode,
    );
    expect(PeopleKey('e1', const ['a']), isNot(PeopleKey('e2', const ['a'])));
  });

  test('my own name shows before the server has copied it', () async {
    await firestore.collection('users').doc('me').set({'displayName': 'Me'});
    await profiles('e1').doc('pat').set({'displayName': 'Pat'});

    expect(await names('e1', ['pat', 'me']), {'pat': 'Pat', 'me': 'Me'});
    expect(await names('e1', ['pat']), {'pat': 'Pat'});
  });

  test('a name changed in the event shows straight away', () async {
    await profiles('e1').doc('pat').set({'displayName': 'Pat'});
    expect((await names('e1', ['pat']))['pat'], 'Pat');

    await profiles('e1').doc('pat').set({'displayName': 'Patricia'});
    await pumpEventQueue();
    final people = await container.read(
      peopleByIdProvider(PeopleKey('e1', const ['pat'])).future,
    );
    expect(people['pat']!.displayName, 'Patricia');
  });

  test('nobody asked for reads nothing', () async {
    expect(await names('e1', const []), isEmpty);
  });
}
