import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Components are plain widgets (Spec #186 Technical Decision 2): no
/// Riverpod, Firebase or feature code, so they render alone in the gallery
/// and in tests.
void main() {
  test('design components import only Flutter and the design system', () {
    final offenders = <String>[];
    for (final entity in Directory(
      'lib/app/core/design',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in entity.readAsLinesSync()) {
        final import = RegExp(r"^(?:import|export) '([^']+)'").firstMatch(line);
        if (import == null) continue;
        final uri = import[1]!;
        final allowed =
            uri.startsWith('dart:') ||
            uri.startsWith('package:flutter/') ||
            uri.startsWith('package:lucide_icons_flutter/') ||
            uri.startsWith('package:pdf/') ||
            uri.startsWith('package:crewpoint_app/app/core/design/');
        if (!allowed) offenders.add('${entity.path}: $uri');
      }
    }
    expect(offenders, isEmpty);
  });
}
