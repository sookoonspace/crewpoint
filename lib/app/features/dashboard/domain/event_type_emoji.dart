import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Canonical `EventType → IconData` map. Single source of truth used by
/// `EventTile`, `ConversationTile`, and anywhere the event type needs a
/// glyph hint.
///
/// Replaced the prior emoji map (🏔️ 📋 🎉 📌) because some platforms /
/// fonts rendered them as missing-glyph boxes (the iOS Simulator + the
/// Google Fonts stack we use don't always carry the variant-selector-16
/// color emoji forms). Material outlined icons render uniformly across
/// every platform and respect the active theme tint.
IconData iconForEventType(EventType type) => switch (type) {
  EventType.trip => Icons.luggage_outlined,
  EventType.project => Icons.assignment_outlined,
  EventType.social => Icons.people_alt_outlined,
  EventType.custom => Icons.event_note_outlined,
};
