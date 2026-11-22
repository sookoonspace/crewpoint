import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_type.dart';

/// Loads a font family from bundled assets at runtime.
abstract interface class IFontLoader {
  Future<void> load(String fontName, List<String> assets);
}

/// Flutter's [FontLoader] over [rootBundle]. On the web, an asset is fetched
/// only when it is loaded, so a font registered this way downloads only
/// when it is needed, unlike one declared under `fonts:` in pubspec.yaml.
class AssetFontLoader implements IFontLoader {
  const AssetFontLoader();

  @override
  Future<void> load(String fontName, List<String> assets) async {
    final loader = FontLoader(fontName);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

/// Noto Sans Gujarati's files (assets/fonts/gujarati/, SIL OFL 1.1).
const gujaratiFontAssets = [
  'assets/fonts/gujarati/NotoSansGujarati-Regular.ttf',
  'assets/fonts/gujarati/NotoSansGujarati-Bold.ttf',
];

final fontLoaderProvider = Provider<IFontLoader>(
  (_) => const AssetFontLoader(),
);

/// Whether the Gujarati font has loaded (Spec #233 Req 59). Nothing loads
/// it until Gujarati is chosen or an event's default language is Gujarati,
/// so English visitors never download it. [CpType.scriptFallback] names it
/// in every text style, so Gujarati text uses it as soon as it is loaded.
class GujaratiFontNotifier extends Notifier<bool> {
  Future<void>? _loading;

  @override
  bool build() => false;

  /// Loads the font once; later calls wait for the same load.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      await ref
          .read(fontLoaderProvider)
          .load(CpType.gujaratiFont, gujaratiFontAssets);
      state = true;
    } catch (error, stack) {
      // The platform's own fonts still show Gujarati; try again next time.
      _loading = null;
      developer.log(
        'Failed to load the Gujarati font',
        name: 'language',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

final gujaratiFontProvider = NotifierProvider<GujaratiFontNotifier, bool>(
  GujaratiFontNotifier.new,
);
