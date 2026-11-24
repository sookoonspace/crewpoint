import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// #239 (Spec #233 Req 8, 11, 16-19, 60): the registration settings as the
/// app reads and sends them. The server's checks are in
/// `functions/test/registration/settings.test.ts`.
void main() {
  group('fromMaps', () {
    test('nothing stored reads the platform defaults', () {
      final s = RegistrationSettings.fromMaps(null, null);
      expect(s.mode, RegistrationMode.invited);
      expect(s.offerHours, 72);
      expect(s.registrationRoleId, 'participant');
      expect(s.blocks, {RegistrationBlock.people, RegistrationBlock.contact});
      expect(s.slug, isNull);
    });

    test(
      'anything missing comes from the template, the rest from the event',
      () {
        final s = RegistrationSettings.fromMaps(
          {
            'review': true,
            'blocks': const {'stay': true},
            'slug': 'convention-2027',
            'deadline': DateTime.utc(2027, 6, 30, 4, 59).millisecondsSinceEpoch,
          },
          const {
            'mode': 'open',
            'registrationRoleId': 'player',
            'blocks': {'waivers': true, 'contact': false},
            'sections': [
              {
                'id': 'food',
                'name': {'en': 'Food'},
                'fieldIds': ['diet'],
              },
            ],
            'conditions': {
              'kids': {'categoryId': 'child'},
            },
          },
        );
        expect(s.mode, RegistrationMode.open);
        expect(s.review, isTrue);
        expect(s.registrationRoleId, 'player');
        expect(s.blocks, {
          RegistrationBlock.people,
          RegistrationBlock.stay,
          RegistrationBlock.waivers,
        });
        expect(s.sections.single.name.en, 'Food');
        expect(s.conditions, {'kids': const CategoryCondition('child')});
        expect(s.deadline, DateTime.utc(2027, 6, 30, 4, 59));
        expect(s.slug, 'convention-2027');
      },
    );
  });

  test('toCallMap sends everything but the slug, times as milliseconds', () {
    final s = const RegistrationSettings(slug: 'mine').copyWith(
      mode: RegistrationMode.open,
      deadline: DateTime.utc(2027, 6, 30),
      conditions: {'confirmation': const AnswerCondition('booked', 'yes')},
      afterNote: const LocalText('Book with code CONV27'),
    );
    final map = s.toCallMap();
    expect(map.containsKey('slug'), isFalse);
    expect(map['mode'], 'open');
    expect(map['deadline'], DateTime.utc(2027, 6, 30).millisecondsSinceEpoch);
    expect(map['conditions'], {
      'confirmation': {'fieldId': 'booked', 'value': 'yes'},
    });
    expect(map['afterNote'], {'en': 'Book with code CONV27'});
    expect((map['blocks'] as Map)['people'], isTrue);
    // A replacement date means nothing without its note.
    expect(
      s
          .copyWith(laterNoteFrom: DateTime.utc(2027))
          .toCallMap()['laterNoteFrom'],
      isNull,
    );
  });

  test('conditions are one level deep', () {
    final s = const RegistrationSettings().withCondition(
      'confirmation',
      const AnswerCondition('booked', 'yes'),
    );
    expect(s.dependedOn, {'booked'});
    // booked is depended on, so it cannot depend on anything itself.
    expect(s.canDependOn('booked', 'shirt'), isFalse);
    // Nothing may depend on confirmation, which has a condition.
    expect(s.canDependOn('shirt', 'confirmation'), isFalse);
    expect(s.canDependOn('shirt', 'booked'), isTrue);
    expect(s.canDependOn('shirt', 'shirt'), isFalse);
    expect(s.withCondition('confirmation', null).conditions, isEmpty);
  });

  test('the registration role manages nothing and is never Owner', () {
    expect(canBeRegistrationRole('participant', ['chat.send']), isTrue);
    expect(
      canBeRegistrationRole('admin', ['chat.send', 'members.manage']),
      isFalse,
    );
    expect(canBeRegistrationRole('owner', const []), isFalse);
  });

  test('slugs are lower-case letters, numbers and hyphens', () {
    expect(normaliseSlug(' Convention-2027 '), 'convention-2027');
    for (final bad in ['ab', 'a b', '-x-', 'under_score', 'x' * 41]) {
      expect(normaliseSlug(bad), isNull, reason: bad);
    }
  });
}
