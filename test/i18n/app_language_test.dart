// Spec #233 Req 56: the language is chosen before sign-in, kept on the
// device, saved to the account after sign-in, and adopted from the account
// on a device that has none.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crewpoint_app/app/core/i18n/app_language.dart';
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';

class FakeLanguageAccountStore implements ILanguageAccountStore {
  final saved = <String, AppLanguage>{};
  int reads = 0;

  @override
  Future<AppLanguage?> read(String uid) async {
    reads++;
    return saved[uid];
  }

  @override
  Future<void> save(String uid, AppLanguage language) async =>
      saved[uid] = language;
}

Future<(ProviderContainer, FakeLanguageAccountStore, SharedPreferences)>
_container([Map<String, Object> device = const {}]) async {
  SharedPreferences.setMockInitialValues(device);
  final prefs = await SharedPreferences.getInstance();
  final store = FakeLanguageAccountStore();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      languageAccountStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return (container, store, prefs);
}

void main() {
  test('English until someone chooses', () async {
    final (c, _, _) = await _container();
    expect(c.read(appLanguageProvider), AppLanguage.en);
    expect(c.read(appLanguageProvider.notifier).chosenOnDevice, isFalse);
  });

  test('a choice is kept on the device', () async {
    final (c, _, prefs) = await _container();
    c.read(appLanguageProvider.notifier).set(AppLanguage.gu);
    expect(c.read(appLanguageProvider), AppLanguage.gu);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(languageStorageKey), 'gu');
  });

  test('a kept choice is read back on the next start', () async {
    final (c, _, _) = await _container({languageStorageKey: 'gu'});
    expect(c.read(appLanguageProvider), AppLanguage.gu);
  });

  test('a choice made before sign-in is saved to the account', () async {
    final (c, store, _) = await _container();
    c.read(appLanguageProvider.notifier).set(AppLanguage.gu);
    await c.read(appLanguageProvider.notifier).accountChanged('u1');
    expect(store.saved['u1'], AppLanguage.gu);
  });

  test('a device with no choice adopts the account language', () async {
    final (c, store, prefs) = await _container();
    store.saved['u1'] = AppLanguage.gu;
    await c.read(appLanguageProvider.notifier).accountChanged('u1');
    expect(c.read(appLanguageProvider), AppLanguage.gu);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(languageStorageKey), 'gu');
  });

  test(
    'changing the language while signed in saves it to the account',
    () async {
      final (c, store, _) = await _container();
      await c.read(appLanguageProvider.notifier).accountChanged('u1');
      c.read(appLanguageProvider.notifier).set(AppLanguage.gu);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved['u1'], AppLanguage.gu);
    },
  );

  test('after sign-out, changes stay on the device only', () async {
    final (c, store, _) = await _container();
    await c.read(appLanguageProvider.notifier).accountChanged('u1');
    await c.read(appLanguageProvider.notifier).accountChanged(null);
    c.read(appLanguageProvider.notifier).set(AppLanguage.gu);
    await Future<void>.delayed(Duration.zero);
    expect(store.saved, isEmpty);
  });

  test('unknown codes read as no language', () {
    expect(AppLanguage.fromCode('fr'), isNull);
    expect(AppLanguage.fromCode('gu'), AppLanguage.gu);
  });
}
