import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/profile/data/firestore_user_repository.dart';

/// Req 37: other people's names and payment handles come from the event's
/// profiles, because `users/{uid}` is readable only by its owner.
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

  Future<Map<String, String?>> names(String eventId) async {
    final sub = container.listen(usersByIdProvider(eventId), (_, _) {});
    addTearDown(sub.close);
    final people = await container.read(usersByIdProvider(eventId).future);
    return {for (final e in people.entries) e.key: e.value.displayName};
  }

  test(
    'everyone with a profile in the event, including people who left',
    () async {
      await profiles(
        'e1',
      ).doc('pat').set({'displayName': 'Pat', 'venmoHandle': 'pat'});
      await profiles('e1').doc('gil').set({'displayName': 'Gil'});
      await profiles('e2').doc('zed').set({'displayName': 'Zed'});
      await firestore.collection('users').doc('me').set({'displayName': 'Me'});
      await profiles('e1').doc('me').set({'displayName': 'Me'});

      expect(await names('e1'), {'pat': 'Pat', 'gil': 'Gil', 'me': 'Me'});
    },
  );

  test('my own name shows before the server has copied it', () async {
    await firestore.collection('users').doc('me').set({'displayName': 'Me'});
    await profiles('e1').doc('pat').set({'displayName': 'Pat'});

    expect(await names('e1'), {'pat': 'Pat', 'me': 'Me'});
  });

  test('a name changed in the event shows straight away', () async {
    await profiles('e1').doc('pat').set({'displayName': 'Pat'});
    await firestore.collection('users').doc('me').set({'displayName': 'Me'});
    expect((await names('e1'))['pat'], 'Pat');

    await profiles('e1').doc('pat').set({'displayName': 'Patricia'});
    await pumpEventQueue();
    final people = await container.read(usersByIdProvider('e1').future);
    expect(people['pat']!.displayName, 'Patricia');
  });
}
