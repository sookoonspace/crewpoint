import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_pdf_builder.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const renamed = EventModel(
    id: 'e',
    title: 'Convention',
    creatorId: 'owner',
    memberIds: ['owner', 'a', 'b'],
    labels: {
      'member': {'one': 'Committee member', 'other': 'Committee'},
      'group': {'one': 'Guest party', 'other': 'Guest parties'},
      'session': {'one': 'Program', 'other': 'Programs'},
    },
  );

  test('GE-01 renamed concepts resolve, and the rest keep their defaults', () {
    expect(renamed.words.other('group'), 'Guest parties');
    expect(renamed.words.one('session'), 'Program');
    expect(renamed.words.one('crew'), 'Crew');
  });

  testWidgets('GE-01 screens use the new word', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventTile(event: renamed, todo: 0, doing: 0, done: 0),
        ),
      ),
    );
    expect(find.textContaining('3 committee'), findsOneWidget);
  });

  testWidgets('GE-01 the invite sheet uses the new word', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddMemberSheet(eventId: 'e', memberLabel: 'Committee'),
        ),
      ),
    );
    expect(find.text('Invite Committee'), findsOneWidget);
  });

  test('GE-01 exports use the new word', () {
    expect(memberBalancesHeading(renamed), 'Committee member balances');
    expect(
      memberBalancesHeading(renamed.copyWith(labels: const {})),
      'Member balances',
    );
  });

  test('GE-01 changing a label needs no restart', () {
    final changed = renamed.copyWith(
      labels: const {
        'member': {'one': 'Volunteer', 'other': 'Volunteers'},
      },
    );
    expect(changed.words.count('member', 3), '3 volunteers');
  });
}
