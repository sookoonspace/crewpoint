// Removes fonts the app never uses from a web build, because Flutter's web
// engine downloads every font in FontManifest.json before the first frame
// (#240 speed budget). lucide_icons_flutter declares six weighted icon
// fonts (Lucide100 to Lucide600, about 1.2 MB together) next to the plain
// `Lucide` font that CpIcons uses; test/design/unused_fonts_test.dart fails
// if code starts using one of them.
//
//   dart run tool/trim_web_fonts.dart build/web
import 'dart:convert';
import 'dart:io';

/// Font families the app never uses.
final unusedFamilies = RegExp(r'^packages/lucide_icons_flutter/Lucide\d{3}$');

void main(List<String> args) {
  final root = args.isEmpty ? 'build/web' : args.first;
  final manifestFile = File('$root/assets/FontManifest.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('No ${manifestFile.path}; build the web app first.');
    exit(1);
  }
  final manifest = (jsonDecode(manifestFile.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final kept = <Map<String, dynamic>>[];
  var removedBytes = 0;
  for (final family in manifest) {
    if (!unusedFamilies.hasMatch(family['family'] as String)) {
      kept.add(family);
      continue;
    }
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      final file = File('$root/assets/${font['asset']}');
      if (file.existsSync()) {
        removedBytes += file.lengthSync();
        file.deleteSync();
      }
    }
  }
  manifestFile.writeAsStringSync(jsonEncode(kept));
  stdout.writeln(
    'Removed ${manifest.length - kept.length} unused font families '
    '(${(removedBytes / 1024).round()} KB).',
  );
}
