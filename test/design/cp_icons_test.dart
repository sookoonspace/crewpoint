import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';

/// The icon set is Lucide (ledger L22), reached only through [CpIcons];
/// the old [AppIcons] names forward to the same glyphs.
void main() {
  const sample = <String, (IconData, IconData)>{
    'navHome': (CpIcons.navHome, AppIcons.navHome),
    'navTasks': (CpIcons.navTasks, AppIcons.navTasks),
    'statusDone': (CpIcons.statusDone, AppIcons.statusDone),
    'statusUrgent': (CpIcons.statusUrgent, AppIcons.statusUrgent),
    'actionAdd': (CpIcons.actionAdd, AppIcons.actionAdd),
    'actionShare': (CpIcons.actionShare, AppIcons.actionShare),
    'chevronRight': (CpIcons.chevronRight, AppIcons.chevronRight),
    'templateGroups': (CpIcons.templateGroups, AppIcons.templateGroups),
    'place': (CpIcons.place, AppIcons.place),
    'lock': (CpIcons.lock, AppIcons.lock),
  };

  for (final MapEntry(key: name, value: (token, old)) in sample.entries) {
    test('$name is a Lucide glyph and AppIcons.$name forwards to it', () {
      expect(token.fontFamily, 'Lucide');
      expect(token.fontPackage, 'lucide_icons_flutter');
      expect(old, token);
    });
  }

  test('brand marks Lucide does not draw stay Material', () {
    expect(CpIcons.authApple, Icons.apple);
  });
}
