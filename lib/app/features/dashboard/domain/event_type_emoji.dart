import 'package:flutter/material.dart';

/// Canonical map from an event's display type to its icon. Single source of truth used by
/// `EventTile`, `ConversationTile`, and anywhere the event type needs a
/// glyph hint.
///
/// Replaced the prior emoji map (🏔️ 📋 🎉 📌) because some platforms /
/// fonts rendered them as missing-glyph boxes (the iOS Simulator + the
/// Google Fonts stack we use don't always carry the variant-selector-16
/// color emoji forms). Material outlined icons render uniformly across
/// every platform and respect the active theme tint.
IconData iconForEventType(String? displayType) => switch (displayType) {
  'trip' => Icons.luggage_outlined,
  'project' => Icons.assignment_outlined,
  'social' => Icons.people_alt_outlined,
  _ => Icons.event_note_outlined,
};
