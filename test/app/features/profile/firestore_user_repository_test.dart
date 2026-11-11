import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/profile/data/firestore_user_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreUserRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreUserRepository(firestore: firestore);
  });

  group('createUserIfNotExists splits PII into private subdoc', () {
    test('public users/{uid} only contains displayName; '
        'private subdoc carries email + preferences + timestamps', () async {
      await repo.createUserIfNotExists(
        uid: 'u1',
        email: 'alice@example.com',
        displayName: 'Alice',
      );

      final publicDoc = await firestore.collection('users').doc('u1').get();
      expect(publicDoc.exists, isTrue);
      expect(publicDoc.data()!.containsKey('email'), isFalse);
      expect(publicDoc.data()!.containsKey('preferences'), isFalse);
      expect(publicDoc.data()!['displayName'], equals('Alice'));

      final privateDoc = await firestore
          .collection('users')
          .doc('u1')
          .collection('private')
          .doc('profile')
          .get();
      expect(privateDoc.exists, isTrue);
      expect(privateDoc.data()!['email'], equals('alice@example.com'));
      expect(privateDoc.data()!['preferences'], isA<Map<String, dynamic>>());
    });

    test('writes photoUrl to public doc and providerIds to private subdoc '
        'when supplied', () async {
      await repo.createUserIfNotExists(
        uid: 'u-google',
        email: 'jane@gmail.com',
        displayName: 'Jane Doe',
        photoUrl: 'https://lh3.googleusercontent.com/a/abc',
        providerIds: const ['google.com'],
      );

      final publicDoc = await firestore
          .collection('users')
          .doc('u-google')
          .get();
      expect(
        publicDoc.data()!['photoUrl'],
        equals('https://lh3.googleusercontent.com/a/abc'),
      );
      expect(publicDoc.data()!.containsKey('providerIds'), isFalse);

      final privateDoc = await firestore
          .collection('users')
          .doc('u-google')
          .collection('private')
          .doc('profile')
          .get();
      expect(privateDoc.data()!['providerIds'], equals(['google.com']));
    });

    test('omits photoUrl key when null and stores empty providerIds list '
        'when not supplied', () async {
      await repo.createUserIfNotExists(
        uid: 'u-apple',
        email: 'jane@privaterelay.appleid.com',
        displayName: 'Jane',
      );

      final publicDoc = await firestore
          .collection('users')
          .doc('u-apple')
          .get();
      expect(publicDoc.data()!.containsKey('photoUrl'), isFalse);

      final privateDoc = await firestore
          .collection('users')
          .doc('u-apple')
          .collection('private')
          .doc('profile')
          .get();
      expect(privateDoc.data()!['providerIds'], equals(<String>[]));
    });

    test('early-returns when public doc already exists '
        '(does not overwrite with new params)', () async {
      // First write — user-edited displayName + no photo.
      await repo.createUserIfNotExists(
        uid: 'u-existing',
        email: 'old@x.com',
        displayName: 'Old Name',
      );

      // Second call — provider data differs; must NOT clobber.
      await repo.createUserIfNotExists(
        uid: 'u-existing',
        email: 'new@x.com',
        displayName: 'New Name',
        photoUrl: 'https://provider/photo',
        providerIds: const ['google.com'],
      );

      final publicDoc = await firestore
          .collection('users')
          .doc('u-existing')
          .get();
      expect(publicDoc.data()!['displayName'], equals('Old Name'));
      expect(publicDoc.data()!.containsKey('photoUrl'), isFalse);

      final privateDoc = await firestore
          .collection('users')
          .doc('u-existing')
          .collection('private')
          .doc('profile')
          .get();
      expect(privateDoc.data()!['email'], equals('old@x.com'));
      expect(privateDoc.data()!['providerIds'], equals(<String>[]));
    });
  });

  group('saveProfile keeps display + payment public; updatedAt private', () {
    test('public doc gains paymentMethod/paymentHandle; '
        'private doc records updatedAt', () async {
      await repo.createUserIfNotExists(
        uid: 'u2',
        email: 'bob@example.com',
        displayName: 'Bob',
      );
      await repo.saveProfile(
        uid: 'u2',
        displayName: 'Bob B.',
        paymentMethod: 'venmo',
        paymentHandle: '@bob',
      );

      final publicDoc = await firestore.collection('users').doc('u2').get();
      expect(publicDoc.data()!['paymentMethod'], equals('venmo'));
      expect(publicDoc.data()!['paymentHandle'], equals('@bob'));
      expect(publicDoc.data()!.containsKey('email'), isFalse);

      final privateDoc = await firestore
          .collection('users')
          .doc('u2')
          .collection('private')
          .doc('profile')
          .get();
      // Email survives from createUserIfNotExists.
      expect(privateDoc.data()!['email'], equals('bob@example.com'));
      // updatedAt was overwritten.
      expect(privateDoc.data()!.containsKey('updatedAt'), isTrue);
    });
  });

  group('FCM tokens write into the private subdoc, not the public doc', () {
    test(
      'addFcmToken appends a {value, platform} object to the private subdoc',
      () async {
        await repo.createUserIfNotExists(
          uid: 'u3',
          email: 'c@example.com',
          displayName: 'Carol',
        );
        await repo.addFcmToken(uid: 'u3', token: 'tok-A', platform: 'mobile');

        final publicDoc = await firestore.collection('users').doc('u3').get();
        expect(publicDoc.data()!.containsKey('fcmTokens'), isFalse);

        final privateDoc = await firestore
            .collection('users')
            .doc('u3')
            .collection('private')
            .doc('profile')
            .get();
        expect(
          privateDoc.data()!['fcmTokens'],
          equals([
            {'value': 'tok-A', 'platform': 'mobile'},
          ]),
        );
      },
    );

    test('addFcmToken tags web tokens with platform "web"', () async {
      await repo.createUserIfNotExists(
        uid: 'u-web',
        email: 'w@example.com',
        displayName: 'Wendy',
      );
      await repo.addFcmToken(uid: 'u-web', token: 'tok-web-1', platform: 'web');

      final privateDoc = await firestore
          .collection('users')
          .doc('u-web')
          .collection('private')
          .doc('profile')
          .get();
      expect(
        privateDoc.data()!['fcmTokens'],
        equals([
          {'value': 'tok-web-1', 'platform': 'web'},
        ]),
      );
    });

    test(
      'removeFcmToken pulls only the matching {value, platform} entry',
      () async {
        await repo.createUserIfNotExists(
          uid: 'u4',
          email: 'd@example.com',
          displayName: 'Dave',
        );
        await repo.addFcmToken(uid: 'u4', token: 'tok-A', platform: 'mobile');
        await repo.addFcmToken(uid: 'u4', token: 'tok-B', platform: 'mobile');
        await repo.removeFcmToken(
          uid: 'u4',
          token: 'tok-A',
          platform: 'mobile',
        );

        final privateDoc = await firestore
            .collection('users')
            .doc('u4')
            .collection('private')
            .doc('profile')
            .get();
        expect(
          privateDoc.data()!['fcmTokens'],
          equals([
            {'value': 'tok-B', 'platform': 'mobile'},
          ]),
        );
      },
    );
  });

  group('getUser merges public + private projections', () {
    test(
      'returns AppUser populated from public doc + private subdoc',
      () async {
        await repo.createUserIfNotExists(
          uid: 'u5',
          email: 'e@example.com',
          displayName: 'Eve',
        );
        await repo.saveProfile(
          uid: 'u5',
          displayName: 'Eve E.',
          paymentMethod: 'cashapp',
          paymentHandle: '\$eve',
        );

        final user = await repo.getUser('u5');
        expect(user, isNotNull);
        expect(user!.uid, equals('u5'));
        expect(user.email, equals('e@example.com'));
        expect(user.displayName, equals('Eve E.'));
        expect(user.paymentMethod, equals('cashapp'));
        expect(user.paymentHandle, equals('\$eve'));
      },
    );

    test('returns null when public doc is missing', () async {
      final user = await repo.getUser('does-not-exist');
      expect(user, isNull);
    });

    test('returns AppUser with empty email when private subdoc is missing '
        '(simulates non-self read denial under the new rules)', () async {
      // Seed public doc only — no private subdoc. Simulates the
      // production state where a non-self caller can't read the
      // private subdoc; the repo's permission-denied fallback returns
      // the public projection with empty PII.
      await firestore.collection('users').doc('u6').set({
        'displayName': 'Frank',
        'photoUrl': 'https://example.com/frank.jpg',
      });

      final user = await repo.getUser('u6');
      expect(user, isNotNull);
      expect(user!.email, equals(''));
      expect(user.displayName, equals('Frank'));
      expect(user.photoUrl, equals('https://example.com/frank.jpg'));
    });
  });

  group('people in an event come from its profiles (Req 37)', () {
    test('one person: name, photo and payment handles', () async {
      final profiles = firestore
          .collection('events')
          .doc('e1')
          .collection('profiles');
      await profiles.doc('pat').set({
        'uid': 'pat',
        'displayName': 'Pat',
        'photoUrl': 'p.jpg',
        'paymentMethod': 'venmo',
        'paymentHandle': '@pat',
        'venmoHandle': 'pat',
        'cashappHandle': null,
      });
      // Their public document is no longer read.
      await firestore.collection('users').doc('pat').set({
        'displayName': 'Wrong',
      });

      final pat = (await repo.watchEventProfile('e1', 'pat').first)!;
      expect(pat.uid, 'pat');
      expect(pat.displayName, 'Pat');
      expect(pat.photoUrl, 'p.jpg');
      expect(pat.paymentMethod, 'venmo');
      expect(pat.paymentHandle, '@pat');
      expect(pat.venmoHandle, 'pat');
      expect(pat.cashappHandle, isNull);
      expect(await repo.watchEventProfile('e1', 'nobody').first, isNull);
    });
  });

  // Req 43a: the member picker pages through people still in the event by
  // name, and searches by the start of a name.
  group('member pages', () {
    Future<void> seed(int count) async {
      final profiles = firestore
          .collection('events')
          .doc('e1')
          .collection('profiles');
      for (var i = 0; i < count; i++) {
        final name = 'Person ${i.toString().padLeft(3, '0')}';
        await profiles.doc('u$i').set({
          'uid': 'u$i',
          'displayName': name,
          'sortName': name.toLowerCase(),
          'inEvent': true,
        });
      }
      await profiles.doc('gil').set({
        'uid': 'gil',
        'displayName': 'Gil',
        'sortName': 'gil',
        'inEvent': false,
      });
      await profiles.doc('ana').set({
        'uid': 'ana',
        'displayName': 'Ana',
        'sortName': 'ana',
        'inEvent': true,
      });
    }

    test('pages in name order, leaving out people who left', () async {
      await seed(60);
      final first = await repo.fetchMemberPage('e1');
      expect(first.people, hasLength(FirestoreUserRepository.memberPageSize));
      expect(first.people.first.displayName, 'Ana');
      expect(first.people.map((p) => p.uid), isNot(contains('gil')));
      expect(first.hasMore, isTrue);

      final second = await repo.fetchMemberPage('e1', after: first);
      expect(second.people.first.displayName, 'Person 029');
      expect(second.hasMore, isTrue);

      // 60 people plus Ana make 30 + 30 + 1.
      final third = await repo.fetchMemberPage('e1', after: second);
      expect(third.people.single.displayName, 'Person 059');
      expect(third.hasMore, isFalse);
    });

    test('searches by the start of a name, ignoring case', () async {
      await seed(12);
      final found = await repo.fetchMemberPage('e1', search: ' PERSON 01');
      expect(found.people.map((p) => p.displayName), [
        'Person 010',
        'Person 011',
      ]);
      expect(found.hasMore, isFalse);
      expect((await repo.fetchMemberPage('e1', search: 'gi')).people, isEmpty);
    });
  });
}
