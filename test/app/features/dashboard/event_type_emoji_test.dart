import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  test('maps each old type name to its icon', () {
    expect(iconForEventType('trip'), CpIcons.eventTrip);
    expect(iconForEventType('project'), CpIcons.eventProject);
    expect(iconForEventType('social'), CpIcons.eventSocial);
    expect(iconForEventType('custom'), CpIcons.event);
  });

  test('an event with no old type gets the general icon', () {
    expect(iconForEventType(null), CpIcons.event);
  });

  group('eventIcon (Spec #186 Req 44)', () {
    const icons = {'convention': 'groups', 'party': 'celebration'};
    EventModel event({String templateId = 'blank', String? type}) => EventModel(
      id: 'e',
      title: 'E',
      creatorId: 'o',
      templateId: templateId,
      displayType: type,
    );

    test("uses the template's icon, a saved template's base included", () {
      expect(
        eventIcon(event(templateId: 'convention'), icons),
        CpIcons.templateGroups,
      );
      expect(
        eventIcon(event(templateId: 'party', type: 'trip'), icons),
        CpIcons.templateCelebration,
      );
    });

    test("else the older type's icon", () {
      expect(eventIcon(event(type: 'trip'), icons), CpIcons.eventTrip);
    });

    test('else a plain event icon', () {
      expect(eventIcon(event(), icons), CpIcons.event);
      expect(eventIcon(event(templateId: 'unknown'), icons), CpIcons.event);
    });
  });
}
