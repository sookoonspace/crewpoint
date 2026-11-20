import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';

/// The icon set is Lucide (ledger L22), reached only through [CpIcons].
void main() {
  const sample = <String, IconData>{
    'navHome': CpIcons.navHome,
    'navTasks': CpIcons.navTasks,
    'statusDone': CpIcons.statusDone,
    'statusUrgent': CpIcons.statusUrgent,
    'actionAdd': CpIcons.actionAdd,
    'actionShare': CpIcons.actionShare,
    'chevronRight': CpIcons.chevronRight,
    'templateGroups': CpIcons.templateGroups,
    'place': CpIcons.place,
    'lock': CpIcons.lock,
  };

  for (final MapEntry(key: name, value: token) in sample.entries) {
    test('$name is a Lucide glyph', () {
      expect(token.fontFamily, 'Lucide');
      expect(token.fontPackage, 'lucide_icons_flutter');
    });
  }

  test('brand marks Lucide does not draw stay Material', () {
    expect(CpIcons.authApple, Icons.apple);
  });
}
