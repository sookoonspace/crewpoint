import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_cover_service.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';

import '../../../../harness/fake_image_service.dart';

/// Spec #186 Req 41, 42: an event manager sets, replaces or removes the
/// cover photo; it is picked at 1,600 px, JPEG quality 85, stored at
/// `events/{id}/cover.jpg`, and only JPEG, PNG or WebP under 5 MB.
void main() {
  late FakeFirebaseFirestore firestore;
  late FakeImageService images;
  late EventCoverService service;
  late AppDatabase db;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    images = FakeImageService();
    db = AppDatabase(NativeDatabase.memory());
    service = EventCoverService(
      images: images,
      events: EventRepository(
        eventsDao: EventsDao(db),
        firestore: firestore,
        createEventCall: (_, {savedTemplateId}) async {},
      ),
    );
    await firestore.doc('events/e1').set({'title': 'Hall', 'creatorId': 'o'});
  });
  tearDown(() => db.close());

  PickedImage picked({String type = 'image/jpeg', int size = 10}) =>
      PickedImage(bytes: Uint8List(size), filename: 'photo', contentType: type);

  Future<Map<String, dynamic>> event() async =>
      (await firestore.doc('events/e1').get()).data()!;

  test(
    'picks at 1,600 px and quality 85, stores the file and the field',
    () async {
      images.next = picked();
      expect(await service.choose('e1'), CoverOutcome.saved);
      expect(images.lastPick, (maxWidth: 1600, maxHeight: 1600, quality: 85));
      expect(images.files.keys, ['events/e1/cover.jpg']);
      expect(images.contentTypes['events/e1/cover.jpg'], 'image/jpeg');
      expect((await event())['cover']['path'], 'events/e1/cover.jpg');
    },
  );

  test('replacing writes the same file again, with a new time', () async {
    images.next = picked();
    await service.choose('e1');
    images.next = picked(type: 'image/png', size: 20);
    expect(await service.choose('e1'), CoverOutcome.saved);
    expect(images.files['events/e1/cover.jpg'], hasLength(20));
    expect(images.files, hasLength(1));
  });

  test('cancelling the picker changes nothing', () async {
    expect(await service.choose('e1'), CoverOutcome.cancelled);
    expect(images.files, isEmpty);
    expect((await event()).containsKey('cover'), isFalse);
  });

  test('refuses a file of 5 MB or more, and anything but an image', () async {
    images.next = picked(size: 5 * 1024 * 1024);
    expect(await service.choose('e1'), CoverOutcome.tooLarge);
    images.next = picked(type: 'image/gif');
    expect(await service.choose('e1'), CoverOutcome.notAnImage);
    expect(images.files, isEmpty);
  });

  test('a failed upload leaves the event as it was', () async {
    images.next = picked();
    images.failUpload = Exception('offline');
    expect(await service.choose('e1'), CoverOutcome.failed);
    expect((await event()).containsKey('cover'), isFalse);
  });

  test('removing clears the field and deletes the file', () async {
    images.next = picked();
    await service.choose('e1');
    expect(await service.remove('e1'), isTrue);
    expect(images.files, isEmpty);
    expect((await event()).containsKey('cover'), isFalse);
  });
}
