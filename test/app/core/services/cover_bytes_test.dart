import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/cover_cache.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../../../harness/fake_image_service.dart';

/// Spec #186 Req 43: a cover is downloaded once per version and kept, so it
/// shows offline on a cold start, and a replaced photo is never stale.
void main() {
  late FakeImageService images;
  late MemoryCoverCache cache;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        imageServiceProvider.overrideWithValue(images),
        coverCacheProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  final v1 = EventCover(
    path: 'events/e1/cover.jpg',
    updatedAt: DateTime.utc(2027, 1, 1),
  );
  final v2 = EventCover(
    path: 'events/e1/cover.jpg',
    updatedAt: DateTime.utc(2027, 2, 1),
  );

  setUp(() {
    images = FakeImageService();
    cache = MemoryCoverCache();
  });

  test('downloads once, then reads the kept copy', () async {
    images.files[v1.path] = Uint8List.fromList([1]);
    expect(await container().read(coverBytesProvider(v1).future), [1]);
    expect(await container().read(coverBytesProvider(v1).future), [1]);
    expect(images.downloads, 1);
  });

  test('a replaced photo is downloaded again, never the stale one', () async {
    images.files[v1.path] = Uint8List.fromList([1]);
    await container().read(coverBytesProvider(v1).future);
    images.files[v1.path] = Uint8List.fromList([2]);
    expect(await container().read(coverBytesProvider(v2).future), [2]);
    expect(await cache.read(v1.path, v1.updatedAt), isNull);
  });

  test('offline on a cold start, the kept copy still shows', () async {
    await cache.write(v1.path, v1.updatedAt, Uint8List.fromList([7]));
    images.files.clear();
    expect(await container().read(coverBytesProvider(v1).future), [7]);
    expect(images.downloads, 0);
  });

  test('a cover that cannot be read gives nothing, for the fallback', () async {
    expect(await container().read(coverBytesProvider(v1).future), isNull);
  });
}
