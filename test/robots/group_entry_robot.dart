import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'roles_robot.dart';

/// Drives the group screen (Spec #186 Req 25–36) through its stable keys.
class GroupEntryRobot extends RolesRobot {
  GroupEntryRobot(super.tester);

  static String person(int index, String part) =>
      'people.groupEntry.person.$index.$part';

  /// People's "+", then "Add {group}".
  Future<void> openNewGroup() async {
    await tap(const Key('people.roster.add'));
    await tap(const Key('people.roster.addGroup'));
    await finishTransition();
  }

  Future<void> type(Key key, String text) async {
    await reveal(find.byKey(key));
    await tester.enterText(find.byKey(key), text);
    await settle();
  }

  Future<void> nameGroup(String name) =>
      type(const Key('people.groupEntry.groupName'), name);

  Future<void> namePerson(int index, String name) =>
      type(Key(person(index, 'name')), name);

  Future<void> emailPerson(int index, String email) =>
      type(Key(person(index, 'email')), email);

  Future<void> phonePerson(int index, String phone) =>
      type(Key(person(index, 'phone')), phone);

  Future<void> markChild(int index) => tap(Key(person(index, 'child')));

  /// Picks [option] for a person's [fieldId] question.
  Future<void> answer(int index, String fieldId, String option) =>
      tap(Key(person(index, 'answer.$fieldId.$option')));

  Future<void> typeAnswer(int index, String fieldId, String text) =>
      type(Key(person(index, 'answer.$fieldId')), text);

  Future<void> answerGroup(String fieldId, String option) =>
      tap(Key('people.groupEntry.group.answer.$fieldId.$option'));

  Future<void> copyPrevious(int index) => tap(Key(person(index, 'copy')));

  Future<void> addPerson() => tap(const Key('people.groupEntry.addPerson'));

  Future<void> removePerson(int index) => tap(Key(person(index, 'remove')));

  Future<void> save() => tap(const Key('people.groupEntry.save'));

  /// The message beside Save: offline, missing answers or what failed.
  String? message() {
    final finder = find.descendant(
      of: find.byKey(const Key('people.groupEntry.message')),
      matching: find.byType(Text),
    );
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<Text>(finder.first).data;
  }
}
