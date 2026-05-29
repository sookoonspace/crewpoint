import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  test('maps every EventType to its canonical Material icon', () {
    expect(iconForEventType(EventType.trip), Icons.luggage_outlined);
    expect(iconForEventType(EventType.project), Icons.assignment_outlined);
    expect(iconForEventType(EventType.social), Icons.people_alt_outlined);
    expect(iconForEventType(EventType.custom), Icons.event_note_outlined);
  });
}
