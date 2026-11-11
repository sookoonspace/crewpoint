import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 57a: the inbox works out unread counts and urgent status from the
/// server's chat summary and the viewer's read marker, without loading
/// messages.
void main() {
  DateTime at(int minute) => DateTime.utc(2027, 7, 17, 12, minute);

  final summary = ChatSummary.fromFirestore('e1', {
    'count': 10,
    'latest': {
      'id': 'm10',
      'senderId': 'bo',
      'text': 'Bring snacks',
      'timestamp': Timestamp.fromDate(at(10)),
      'isHighPriority': false,
      'kind': null,
    },
    'lastUrgentAt': Timestamp.fromDate(at(8)),
    'lastUrgentSenderId': 'bo',
  });

  test('reads the summary', () {
    expect(summary.count, 10);
    expect(summary.latest!.text, 'Bring snacks');
    expect(summary.latest!.eventId, 'e1');
    expect(summary.lastUrgentAt, at(8));
  });

  test('unread is the count since the viewer last read', () {
    final r = inboxUnread(
      summary: summary,
      read: ChatReadState(lastReadAt: at(5), readCount: 7),
      uid: 'me',
    );
    expect(r.count, 3);
    expect(r.urgent, isTrue);
  });

  test('read after the urgent message clears urgent', () {
    final r = inboxUnread(
      summary: summary,
      read: ChatReadState(lastReadAt: at(9), readCount: 9),
      uid: 'me',
    );
    expect(r.count, 1);
    expect(r.urgent, isFalse);
  });

  test('all read means nothing unread', () {
    final r = inboxUnread(
      summary: summary,
      read: ChatReadState(lastReadAt: at(10), readCount: 10),
      uid: 'me',
    );
    expect(r, (count: 0, urgent: false));
  });

  test('my own urgent message is never urgent for me', () {
    expect(
      inboxUnread(summary: summary, read: null, uid: 'bo').urgent,
      isFalse,
    );
  });

  test('never read means everything is unread', () {
    expect(inboxUnread(summary: summary, read: null, uid: 'me').count, 10);
  });

  test('an older read marker without a count shows at least one', () {
    expect(
      inboxUnread(
        summary: summary,
        read: ChatReadState(lastReadAt: at(9)),
        uid: 'me',
      ).count,
      1,
    );
    expect(
      inboxUnread(
        summary: summary,
        read: ChatReadState(lastReadAt: at(11)),
        uid: 'me',
      ).count,
      0,
    );
  });

  test('deleted messages never make the count negative', () {
    expect(
      inboxUnread(
        summary: summary,
        read: ChatReadState(lastReadAt: at(11), readCount: 12),
        uid: 'me',
      ).count,
      0,
    );
  });

  test('no summary or an empty chat has nothing unread', () {
    expect(inboxUnread(summary: null, read: null, uid: 'me').count, 0);
    expect(
      inboxUnread(
        summary: ChatSummary.fromFirestore('e1', const {'count': 0}),
        read: null,
        uid: 'me',
      ).count,
      0,
    );
  });
}
