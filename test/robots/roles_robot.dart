import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the Members, Member detail, Roles and Role editor screens. Uses
/// bounded pumps, since the Firestore mirrors keep emitting.
class RolesRobot {
  RolesRobot(this.tester);

  final WidgetTester tester;

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Brings [finder] on screen, scrolling the page's list when the item is
  /// not built yet.
  Future<void> reveal(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).evaluate().isNotEmpty
                  ? find.byType(ListView).last
                  : find.byType(SingleChildScrollView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder.first);
    await tester.pump();
  }

  Future<void> tap(Key key) async {
    await reveal(find.byKey(key));
    await tester.tap(find.byKey(key));
    await settle();
  }

  /// Unmounts the app, so no stream or snackbar timer outlives the test.
  Future<void> finish() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openMember(String uid) => tap(Key('members.tile.$uid'));

  Future<void> toggleRole(String roleId) =>
      tap(Key('members.detail.role.$roleId'));

  Future<void> saveRoles() => tap(const Key('members.detail.save'));

  Future<void> openRoles() => tap(const Key('members.roles'));

  Future<void> openRole(String roleId) => tap(Key('roles.tile.$roleId'));

  Future<void> startNewRole() => tap(const Key('roles.new'));

  Future<void> enterRoleName(String name) async {
    await tester.enterText(find.byKey(const Key('roles.editor.name')), name);
    await settle();
  }

  Future<void> togglePermission(String permission) =>
      tap(Key('roles.editor.permission.$permission'));

  Future<void> saveRole() => tap(const Key('roles.editor.save'));

  /// Goes back a page, once any route transition has finished.
  Future<void> back() async {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pageBack();
    await settle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void expectVisible(Key key) => expect(find.byKey(key), findsOneWidget);

  /// Scrolls to [key] and checks it is there.
  Future<void> expectFound(Key key) async {
    await reveal(find.byKey(key));
    expectVisible(key);
  }

  /// Scrolls to [text] and checks it is there.
  Future<void> expectTextFound(String text) async {
    await reveal(find.text(text));
    expectText(text);
  }

  void expectHidden(Key key) => expect(find.byKey(key), findsNothing);

  void expectText(String text) =>
      expect(find.text(text), findsAtLeastNWidgets(1));

  /// The role line under someone in the members list.
  void expectMemberRole(String uid, String role) => expect(
    find.descendant(
      of: find.byKey(Key('members.tile.$uid')),
      matching: find.text(role),
    ),
    findsOneWidget,
  );
}
