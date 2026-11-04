import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';

void main() {
  test('maps each old type name to its icon', () {
    expect(iconForEventType('trip'), Icons.luggage_outlined);
    expect(iconForEventType('project'), Icons.assignment_outlined);
    expect(iconForEventType('social'), Icons.people_alt_outlined);
    expect(iconForEventType('custom'), Icons.event_note_outlined);
  });

  test('an event with no old type gets the general icon', () {
    expect(iconForEventType(null), Icons.event_note_outlined);
  });
}
