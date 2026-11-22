// Spec #233 Req 59: the Gujarati font is bundled, loaded only when asked,
// and loaded once.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_type.dart';
import 'package:crewpoint_app/app/core/i18n/script_fonts.dart';

class FakeFontLoader implements IFontLoader {
  final loads = <(String, List<String>)>[];
  Object? failWith;

  @override
  Future<void> load(String family, List<String> assets) async {
    if (failWith case final error?) throw error;
    loads.add((family, assets));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(FakeFontLoader loader) {
    final c = ProviderContainer(
      overrides: [fontLoaderProvider.overrideWithValue(loader)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('nothing loads until asked', () {
    final loader = FakeFontLoader();
    final c = container(loader);
    expect(c.read(gujaratiFontProvider), isFalse);
    expect(loader.loads, isEmpty);
  });

  test('loads the Gujarati family once', () async {
    final loader = FakeFontLoader();
    final c = container(loader);
    await Future.wait([
      c.read(gujaratiFontProvider.notifier).ensureLoaded(),
      c.read(gujaratiFontProvider.notifier).ensureLoaded(),
    ]);
    expect(loader.loads, [(CpType.gujaratiFont, gujaratiFontAssets)]);
    expect(c.read(gujaratiFontProvider), isTrue);
  });

  test('a failed load can be tried again', () async {
    final loader = FakeFontLoader()..failWith = Exception('offline');
    final c = container(loader);
    await c.read(gujaratiFontProvider.notifier).ensureLoaded();
    expect(c.read(gujaratiFontProvider), isFalse);
    loader.failWith = null;
    await c.read(gujaratiFontProvider.notifier).ensureLoaded();
    expect(c.read(gujaratiFontProvider), isTrue);
  });

  test('the font files are bundled as assets', () async {
    for (final asset in gujaratiFontAssets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(100000), reason: asset);
    }
  });

  test('every text style falls back to the Gujarati font', () {
    const t = CpType.standard;
    for (final style in [
      t.displayLarge,
      t.titleMedium,
      t.bodyMedium,
      t.labelSmall,
      t.stat,
    ]) {
      expect(style.fontFamilyFallback, [
        CpType.gujaratiFont,
        CpType.gujaratiLabelFont,
      ]);
    }
  });

  test(
    'the font is not declared under fonts:, so the web fetches it only when loaded',
    () {
      // A family under `fonts:` goes into FontManifest.json, which the web
      // engine downloads at start-up.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final fonts = pubspec.substring(pubspec.indexOf('\n  fonts:'));
      expect(fonts, isNot(contains('asset: assets/fonts/gujarati/')));
      // Only the 8 KB label font is declared, for the switch's own label.
      expect(fonts, contains('asset: assets/fonts/GujaratiLabel-Regular.ttf'));
    },
  );
}
