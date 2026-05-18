import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Canonical `EventType → emoji` map. Single source of truth used by
/// `EventTile`, `ConversationTile`, and anywhere the event type needs a
/// glyph hint.
String emojiForEventType(EventType type) => switch (type) {
  EventType.trip => '🏔️',
  EventType.project => '📋',
  EventType.social => '🎉',
  EventType.custom => '📌',
};
