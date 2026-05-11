import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/assignee_picker.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(body: Material(child: child)),
  );

  testWidgets(
    'renders hydrated display name when present, truncated UID fallback otherwise',
    (tester) async {
      await tester.pumpWidget(
        harness(
          AssigneePicker(
            memberIds: const [
              'abcdefghij1234567890', // hydrated → "Bo Lyons"
              'zzzzzzzzzzzzz', // no entry → truncated to "zzzzzzzzzz…"
            ],
            displayNames: const {'abcdefghij1234567890': 'Bo Lyons'},
            selected: null,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('tasks.create.assignee')));
      await tester.pumpAndSettle();

      expect(find.text('Bo Lyons'), findsWidgets);
      expect(find.text('zzzzzzzzzz…'), findsWidgets);
    },
  );

  testWidgets(
    'renders orphan assignee as disabled item labeled "(no longer in event)"',
    (tester) async {
      const orphanUid = 'orphan-uid-1234';
      var changed = false;
      await tester.pumpWidget(
        harness(
          AssigneePicker(
            memberIds: const ['current-member-1'],
            displayNames: const {'current-member-1': 'Pat', orphanUid: 'Casey'},
            orphanAssigneeId: orphanUid,
            selected: orphanUid,
            onChanged: (_) => changed = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('tasks.create.assignee')));
      await tester.pumpAndSettle();

      // Orphan row text composed of name + suffix.
      expect(find.text('Casey (no longer in event)'), findsWidgets);

      // Tap the orphan item — onChanged should NOT fire (disabled).
      await tester.tap(find.text('Casey (no longer in event)').last);
      await tester.pumpAndSettle();
      expect(changed, isFalse);
    },
  );
}
