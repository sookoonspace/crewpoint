import 'package:crewpoint_app/app/features/chat/domain/dispute_window.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/dispute_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isDisputeWindowOpen', () {
    final settled = DateTime.utc(2027, 1, 1);
    bool open(int days, {int windowDays = 30}) => isDisputeWindowOpen(
      settledAt: settled,
      windowDays: windowDays,
      now: settled.add(Duration(days: days)),
    );

    test('open within the window', () => expect(open(29), isTrue));
    test('open on the last moment', () => expect(open(30), isTrue));
    test('closed after it', () => expect(open(31), isFalse));
    test('the window can be changed', () {
      expect(open(8, windowDays: 7), isFalse);
      expect(open(45, windowDays: 60), isTrue);
    });
  });

  group('disputeWindowDaysFrom', () {
    test('reads the setting', () {
      expect(disputeWindowDaysFrom({'disputeWindowDays': 7}), 7);
    });

    test('falls back to 30', () {
      expect(disputeWindowDaysFrom(null), 30);
      expect(disputeWindowDaysFrom({}), 30);
      expect(disputeWindowDaysFrom({'disputeWindowDays': 'soon'}), 30);
      expect(disputeWindowDaysFrom({'disputeWindowDays': -1}), 30);
    });
  });

  group('DisputeSheet', () {
    Widget sheet({int? closedAfterDays}) => MaterialApp(
      home: Scaffold(
        body: DisputeSheet(
          summary: 'Settled',
          closedAfterDays: closedAfterDays,
        ),
      ),
    );

    testWidgets('offers the dispute while the window is open', (tester) async {
      await tester.pumpWidget(sheet());
      expect(find.byKey(const Key('chat.dispute.confirm')), findsOneWidget);
      expect(find.byKey(const Key('chat.dispute.closed')), findsNothing);
    });

    testWidgets('explains when the window has closed', (tester) async {
      await tester.pumpWidget(sheet(closedAfterDays: 30));
      expect(find.byKey(const Key('chat.dispute.confirm')), findsNothing);
      expect(find.byKey(const Key('chat.dispute.closed')), findsOneWidget);
      expect(find.textContaining('30 days'), findsOneWidget);
    });
  });
}
