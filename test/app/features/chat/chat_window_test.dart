import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 57, 58 (S-07, FND-11): chat listens to the latest messages only. A
/// message leaving that window is either deleted or just older than the
/// window, and only deletions leave the device's copy.
void main() {
  ChatMessage m(int i) => ChatMessage(
    id: 'm$i',
    eventId: 'e',
    senderId: 'u',
    text: '$i',
    timestamp: DateTime.utc(2027, 1, 1, 0, i),
  );
  List<ChatMessage> range(int from, int to) => [
    for (var i = from; i <= to; i++) m(i),
  ];

  group('deletedFromWindow', () {
    test('an older message pushed out by a new one was not deleted', () {
      // Window of 3: m2..m4 after m4 arrived, m1 left.
      expect(
        deletedFromWindow(removed: [m(1)], window: range(2, 4), limit: 3),
        isEmpty,
      );
    });

    test('a message removed from inside the window was deleted', () {
      // m3 deleted; m1 slides back in to fill the window.
      expect(
        deletedFromWindow(
          removed: [m(3)],
          window: [m(1), m(2), m(4)],
          limit: 3,
        ),
        ['m3'],
      );
    });

    test('with fewer messages than the window, any removal is a deletion', () {
      expect(deletedFromWindow(removed: [m(1)], window: [m(2)], limit: 3), [
        'm1',
      ]);
    });
  });

  group('staleInCache', () {
    test('cached messages missing from a full window but newer than its '
        'oldest were deleted while away', () {
      expect(
        staleInCache(
          cached: [m(1), m(2), m(3), m(5)],
          window: [m(2), m(4), m(5)],
          limit: 3,
        ),
        ['m3'],
      );
    });

    test('older cached pages are kept', () {
      expect(
        staleInCache(cached: range(1, 5), window: range(3, 5), limit: 3),
        isEmpty,
      );
    });

    test('a window that is not full means everything else was deleted', () {
      expect(staleInCache(cached: range(1, 3), window: [m(3)], limit: 50), [
        'm1',
        'm2',
      ]);
    });
  });

  test('a page is 50 messages', () {
    expect(chatPageSize, 50);
  });
}
