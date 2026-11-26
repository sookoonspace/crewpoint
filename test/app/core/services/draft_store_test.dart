import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crewpoint_app/app/core/services/draft_store.dart';

/// #243 (Req 23): drafts kept on the device, one per key.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves, loads and clears a draft by key', () async {
    final store = SharedPreferencesDraftStore(
      await SharedPreferences.getInstance(),
    );
    expect(await store.load('a'), isNull);
    await store.save('a', {
      'name': 'Asha',
      'people': [
        {'age': 9},
      ],
    });
    await store.save('b', {'name': 'Other'});
    expect(await store.load('a'), {
      'name': 'Asha',
      'people': [
        {'age': 9},
      ],
    });
    await store.clear('a');
    expect(await store.load('a'), isNull);
    expect(await store.load('b'), {'name': 'Other'});
  });

  test('something unreadable loads as no draft', () async {
    SharedPreferences.setMockInitialValues({'draft_v1:a': '{nope'});
    final store = SharedPreferencesDraftStore(
      await SharedPreferences.getInstance(),
    );
    expect(await store.load('a'), isNull);
  });
}
