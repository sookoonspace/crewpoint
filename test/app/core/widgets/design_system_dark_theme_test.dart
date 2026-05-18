import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/core/widgets/balance_tile.dart';
import 'package:crewpoint_app/app/core/widgets/conversation_tile.dart';
import 'package:crewpoint_app/app/core/widgets/event_tile.dart';
import 'package:crewpoint_app/app/core/widgets/task_progress_summary.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Smoke check: each headline design-system tile renders under
/// `AppTheme.dark()` without throwing (e.g., null color lookup,
/// overflow, missing token).
void main() {
  Future<void> pumpDark(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  testWidgets('EventTile renders cleanly in dark theme', (tester) async {
    final event = EventModel(
      id: 'evt-a',
      title: 'Tahoe Trip',
      creatorId: 'me',
      eventType: EventType.trip,
      memberIds: const ['me', 'bo'],
      startDate: DateTime(2026, 12, 12),
      endDate: DateTime(2026, 12, 15),
    );
    await pumpDark(tester, EventTile(event: event, todo: 2, doing: 1, done: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ConversationTile renders cleanly in dark theme', (tester) async {
    await pumpDark(
      tester,
      const ConversationTile(
        emoji: '🎉',
        title: 'NYC New Year',
        preview: 'URGENT: Venue deposit due',
        timestamp: '18m',
        unreadCount: 4,
        isUrgent: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('BalanceTile renders cleanly in dark theme', (tester) async {
    await pumpDark(
      tester,
      const BalanceTile(owedToYou: 150.0, youOwe: 45.0, currencyCode: 'USD'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('BalanceTile all-settled state renders cleanly in dark theme', (
    tester,
  ) async {
    await pumpDark(
      tester,
      const BalanceTile(owedToYou: 0, youOwe: 0, currencyCode: 'USD'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TaskProgressSummary renders cleanly in dark theme', (
    tester,
  ) async {
    await pumpDark(
      tester,
      const TaskProgressSummary(todo: 5, doing: 2, done: 3),
    );
    expect(tester.takeException(), isNull);
  });
}
