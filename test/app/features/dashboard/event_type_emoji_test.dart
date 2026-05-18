import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  test('maps every EventType to its canonical emoji', () {
    expect(emojiForEventType(EventType.trip), '🏔️');
    expect(emojiForEventType(EventType.project), '📋');
    expect(emojiForEventType(EventType.social), '🎉');
    expect(emojiForEventType(EventType.custom), '📌');
  });
}
