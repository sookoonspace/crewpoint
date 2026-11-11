import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'roles_robot.dart';

/// Drives the Schedule and Session screens (#81). Uses bounded pumps, since
/// the sessions mirror keeps emitting.
class ScheduleRobot extends RolesRobot {
  ScheduleRobot(super.tester);

  Future<void> addSession() async {
    await tap(const Key('schedule.add'));
    await finishTransition();
  }

  Future<void> openSession(String id) async {
    await tap(Key('schedule.tile.$id'));
    await finishTransition();
  }

  Future<void> enter(String field, String text) async {
    final finder = find.byKey(Key('schedule.edit.$field'));
    await reveal(finder);
    await tester.enterText(finder, text);
    await settle();
  }

  /// Picks [day] of the month shown in the date picker.
  Future<void> pickDay(int day) async {
    await tap(const Key('schedule.edit.day'));
    await tester.tap(find.text('$day'));
    await tester.tap(find.text('OK'));
    await settle();
  }

  /// Types [hour]:[minute] into the time picker's input mode.
  Future<void> pickTime(String which, int hour, int minute) async {
    await tap(Key('schedule.edit.$which'));
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await settle();
    final boxes = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextFormField),
    );
    final h = hour % 12 == 0 ? 12 : hour % 12;
    await tester.enterText(boxes.at(0), '$h');
    await tester.enterText(boxes.at(1), minute.toString().padLeft(2, '0'));
    await tester.tap(find.text(hour < 12 ? 'AM' : 'PM'));
    await tester.tap(find.text('OK'));
    await settle();
  }

  Future<void> addTag(String tag) async {
    await enter('tag', tag);
    await tap(const Key('schedule.edit.tag.add'));
  }

  Future<void> save() async {
    await tap(const Key('schedule.edit.save'));
    await finishTransition();
  }

  Future<void> showByVenue() => tap(const Key('schedule.view.venue'));
}
