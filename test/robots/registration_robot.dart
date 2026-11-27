import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/sign_in_harness.dart';

/// Drives the registration form (#242) over [SignInHarness]: steps, people,
/// answers, stays, session choices, contact, review and submit.
class RegistrationRobot {
  RegistrationRobot(this.tester, this.h);

  final WidgetTester tester;
  final SignInHarness h;

  static const k = 'registration.form';

  Future<void> tap(Key key) => h.tap(tester, key);
  Future<void> type(Key key, String text) => h.type(tester, key, text);

  Future<void> next() => tap(const Key('$k.next'));
  Future<void> submit() => tap(const Key('$k.submit'));

  /// The step shown, as "Step N of M".
  String get progress =>
      tester.widget<Text>(find.byKey(const Key('$k.progress'))).data ?? '';

  Future<void> name(int person, String name) =>
      type(Key('$k.person.$person.name'), name);

  /// Types [date] (`MM/DD/YYYY`) in the date picker's input mode.
  Future<void> pickDate(Key field, String date) async {
    await tap(field);
    await tester.tap(find.byTooltip('Switch to input'));
    await h.settle(tester);
    await tester.enterText(find.byType(TextField).last, date);
    await tester.tap(find.text('OK'));
    await h.settle(tester);
  }

  Future<void> birthDate(int person, String date) =>
      pickDate(Key('$k.person.$person.birthDate'), date);

  Future<void> addPerson() => tap(const Key('$k.addPerson'));

  /// Picks [option] (or `yes`, `no`) for one person's choice question.
  Future<void> choose(int person, String fieldId, String option) =>
      tap(Key('$k.answer.$person.answer.$fieldId.$option'));

  /// Picks [option] for a question asked once for the group.
  Future<void> chooseForGroup(String fieldId, String option) =>
      tap(Key('$k.group.answer.$fieldId.$option'));

  Future<void> session(int person, String sessionId) =>
      tap(Key('$k.session.$person.$sessionId'));

  /// Turns on accepting [waiverId] for [person] on the waivers step (#246).
  Future<void> acceptWaiver(String waiverId, int person) =>
      tap(Key('$k.waiver.$waiverId.accept.$person'));
}
