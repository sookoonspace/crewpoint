import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/profile/data/firestore_user_repository.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/assignee_picker.dart';

/// Req 43a: a task's assignee is chosen from the paged, searchable member
/// picker, so a large event never lists everyone.
void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.doc('events/e1/profiles/bo').set({
      'uid': 'bo',
      'displayName': 'Bo Lyons',
      'sortName': 'bo lyons',
      'inEvent': true,
    });
  });

  Future<void> pump(
    WidgetTester tester, {
    String? selected,
    String? selectedName,
    bool selectedLeft = false,
    void Function(String?, String?)? onChanged,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(
          FirestoreUserRepository(firestore: firestore),
        ),
        currentUserIdProvider.overrideWithValue('me'),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AssigneePicker(
            eventId: 'e1',
            words: const LabelResolver({}),
            selected: selected,
            selectedName: selectedName,
            selectedLeft: selectedLeft,
            onChanged: onChanged ?? (_, _) {},
          ),
        ),
      ),
    ),
  );

  String shown(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('tasks.create.assignee.value')))
      .data!;

  testWidgets('shows the name, or a shortened ID when none is known', (
    tester,
  ) async {
    await pump(tester);
    expect(shown(tester), 'Unassigned');
    expect(find.byKey(const Key('tasks.create.assignee.clear')), findsNothing);

    await pump(tester, selected: 'abcdefghij1234567890', selectedName: 'Bo');
    expect(shown(tester), 'Bo');

    await pump(tester, selected: 'abcdefghij1234567890');
    expect(shown(tester), 'abcdefghij…');
  });

  testWidgets('picks someone from the member picker', (tester) async {
    String? uid;
    String? name;
    await pump(
      tester,
      onChanged: (u, n) {
        uid = u;
        name = n;
      },
    );
    await tester.tap(find.byKey(const Key('tasks.create.assignee')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('members.picker.row.bo')));
    await tester.pumpAndSettle();
    expect(uid, 'bo');
    expect(name, 'Bo Lyons');
  });

  testWidgets('someone who left shows as no longer in the event, and clears', (
    tester,
  ) async {
    var cleared = false;
    await pump(
      tester,
      selected: 'gone',
      selectedName: 'Casey',
      selectedLeft: true,
      onChanged: (u, _) => cleared = u == null,
    );
    expect(shown(tester), 'Casey (no longer in event)');
    await tester.tap(find.byKey(const Key('tasks.create.assignee.clear')));
    expect(cleared, isTrue);
  });
}
