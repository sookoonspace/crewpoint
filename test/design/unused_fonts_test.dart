import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build drops lucide_icons_flutter's weighted icon fonts
/// (Lucide100 to Lucide600) because the engine downloads every declared
/// font before the first frame (tool/trim_web_fonts.dart, #240). An icon
/// from one of them would show as an empty box on the web, so none may be
/// used; CpIcons uses the plain `Lucide` font.
void main() {
  test('no code uses the icon weights the web build drops', () {
    final weighted = RegExp(r'LucideIcons\d{3}\b|Lucide\d{3}\b');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (weighted.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the web build trims only those weights', () {
    final script = File('tool/trim_web_fonts.dart').readAsStringSync();
    expect(
      script,
      contains(r"RegExp(r'^packages/lucide_icons_flutter/Lucide\d{3}$')"),
    );
    expect(
      File('scripts/build_web.sh').readAsStringSync(),
      contains('dart run tool/trim_web_fonts.dart build/web'),
    );
  });
}
