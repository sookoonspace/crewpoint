import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/conversation_tile.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('renders icon + title + preview + timestamp', (tester) async {
    await pump(
      tester,
      const ConversationTile(
        icon: Icons.luggage_outlined,
        title: 'Tahoe Ski Trip',
        preview: 'Bo: Just found a cabin with a view',
        timestamp: '2m',
      ),
    );
    expect(find.byIcon(Icons.luggage_outlined), findsOneWidget);
    expect(find.text('Tahoe Ski Trip'), findsOneWidget);
    expect(find.text('Bo: Just found a cabin with a view'), findsOneWidget);
    expect(find.text('2m'), findsOneWidget);
  });

  testWidgets('shows unread pill when unreadCount > 0', (tester) async {
    await pump(
      tester,
      const ConversationTile(
        icon: Icons.people_alt_outlined,
        title: 'NYC New Year',
        preview: 'Casey: Deposit due',
        timestamp: '18m',
        unreadCount: 4,
      ),
    );
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('caps the unread pill at 99+', (tester) async {
    await pump(
      tester,
      const ConversationTile(
        icon: Icons.people_alt_outlined,
        title: 'NYC New Year',
        preview: 'Lots of unread',
        timestamp: '18m',
        unreadCount: 250,
      ),
    );
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('250'), findsNothing);
  });

  testWidgets('hides unread pill when unreadCount is 0', (tester) async {
    await pump(
      tester,
      const ConversationTile(
        icon: Icons.beach_access_outlined,
        title: 'Beach Weekend',
        preview: "You: I'll Venmo everyone.",
        timestamp: 'Yesterday',
      ),
    );
    expect(find.byKey(const Key('conversation.tile.unreadPill')), findsNothing);
  });

  testWidgets('shows urgent badge when isUrgent is true', (tester) async {
    await pump(
      tester,
      const ConversationTile(
        icon: Icons.people_alt_outlined,
        title: 'NYC New Year',
        preview: 'URGENT: Venue deposit due',
        timestamp: '18m',
        unreadCount: 1,
        isUrgent: true,
      ),
    );
    expect(
      find.byKey(const Key('conversation.tile.urgentBadge')),
      findsOneWidget,
    );
  });

  testWidgets('tap fires onTap callback', (tester) async {
    var taps = 0;
    await pump(
      tester,
      ConversationTile(
        icon: Icons.assignment_outlined,
        title: 'Project',
        preview: 'Hello',
        timestamp: '1h',
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.byType(ConversationTile));
    expect(taps, 1);
  });

  testWidgets('wraps content in a Card for the elevated-tile look', (
    tester,
  ) async {
    await pump(
      tester,
      const ConversationTile(
        icon: Icons.luggage_outlined,
        title: 'Tahoe Ski Trip',
        preview: 'Bo: Just found a cabin',
        timestamp: '2m',
      ),
    );
    expect(
      find.descendant(
        of: find.byType(ConversationTile),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
  });
}
