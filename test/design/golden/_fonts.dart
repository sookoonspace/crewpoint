import 'package:flutter/services.dart';

/// Loads the bundled fonts so goldens show real Inter and Lucide glyphs
/// instead of the test font's boxes (ledger L15).
Future<void> loadDesignFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  await load('InterDisplay', [
    'assets/fonts/InterDisplay-SemiBold.ttf',
    'assets/fonts/InterDisplay-Bold.ttf',
  ]);
  await load('packages/lucide_icons_flutter/Lucide', [
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  ]);
}
