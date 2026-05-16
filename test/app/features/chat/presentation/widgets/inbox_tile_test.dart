import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/inbox_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

const _event = EventModel(
  id: 'evt-a',
  title: 'Tahoe Trip',
  creatorId: 'me',
  memberIds: ['me', 'alex'],
);

final _msg = ChatMessageModel(
  id: 'm-1',
  eventId: 'evt-a',
  senderId: 'alex',
  text: 'Bring snacks',
  timestamp: DateTime(2026, 5, 14, 10),
  senderName: 'Alex',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets(
    'unread state — title rendered with FontWeight.w700 + badge with sage background',
    (tester) async {
      await _pump(
        tester,
        InboxTile(
          row: InboxRow(
            event: _event,
            lastMessage: _msg,
            unreadCount: 3,
            hasUrgentUnread: false,
          ),
          currentUserId: 'me',
          onTap: () {},
        ),
      );

      final titleWidget = tester.widget<Text>(find.text('Tahoe Trip'));
      expect(titleWidget.style?.fontWeight, FontWeight.w700);

      // Badge present with count text.
      expect(
        find.byKey(const Key('chat.inbox.tile.evt-a.badge')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    'read state (unreadCount == 0) — no badge; title weight is not w700',
    (tester) async {
      await _pump(
        tester,
        InboxTile(
          row: InboxRow(
            event: _event,
            lastMessage: _msg,
            unreadCount: 0,
            hasUrgentUnread: false,
          ),
          currentUserId: 'me',
          onTap: () {},
        ),
      );

      expect(
        find.byKey(const Key('chat.inbox.tile.evt-a.badge')),
        findsNothing,
      );
      final title = tester.widget<Text>(find.text('Tahoe Trip'));
      expect(title.style?.fontWeight, isNot(FontWeight.w700));
    },
  );

  testWidgets(
    'urgent state — bell icon visible with terracotta color + badge is terracotta',
    (tester) async {
      await _pump(
        tester,
        InboxTile(
          row: InboxRow(
            event: _event,
            lastMessage: _msg,
            unreadCount: 1,
            hasUrgentUnread: true,
          ),
          currentUserId: 'me',
          onTap: () {},
        ),
      );

      // Bell icon present + has the urgent key.
      expect(
        find.byKey(const Key('chat.inbox.tile.evt-a.urgent')),
        findsOneWidget,
      );
      final bell = tester.widget<Icon>(
        find.byKey(const Key('chat.inbox.tile.evt-a.urgent')),
      );
      expect(bell.icon, Icons.notification_important_outlined);
      expect(bell.color, AppColors.terracotta);
    },
  );

  testWidgets('badge text caps at "99+" when unreadCount > 99', (tester) async {
    await _pump(
      tester,
      InboxTile(
        row: InboxRow(
          event: _event,
          lastMessage: _msg,
          unreadCount: 250,
          hasUrgentUnread: false,
        ),
        currentUserId: 'me',
        onTap: () {},
      ),
    );

    expect(find.text('99+'), findsOneWidget);
  });
}
