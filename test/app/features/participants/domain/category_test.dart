import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';

/// Req 42 (Z-01): categories per event, derived by an age rule on a date.
/// The convention boundary: 17 on the first day is a child, 18 an adult.
void main() {
  group('ageOn', () {
    test('counts whole years, turning a year older on the birthday', () {
      expect(ageOn('2008-06-10', DateTime.utc(2026, 6, 9)), 17);
      expect(ageOn('2008-06-10', DateTime.utc(2026, 6, 10)), 18);
      expect(ageOn('2008-06-10', DateTime.utc(2026, 6, 11)), 18);
    });

    test('a 29 February birthday turns over on 1 March in other years', () {
      expect(ageOn('2008-02-29', DateTime.utc(2026, 2, 28)), 17);
      expect(ageOn('2008-02-29', DateTime.utc(2026, 3, 1)), 18);
    });

    test('an unreadable date has no age', () {
      expect(ageOn('soon', DateTime.utc(2026)), isNull);
      expect(ageOn(null, DateTime.utc(2026)), isNull);
    });
  });

  group('categoryFor', () {
    const convention = [
      EventCategory(id: 'child', name: 'Child', maxAge: 17, isChild: true),
      EventCategory(id: 'adult', name: 'Adult', minAge: 18),
      EventCategory(id: 'volunteer', name: 'Volunteer'),
    ];
    final start = DateTime.utc(2026, 7, 3);

    test('the convention boundary: 17 on the first day is a child, 18 an adult', () {
      expect(categoryFor('2008-07-04', start, convention)?.id, 'child');
      expect(categoryFor('2008-07-03', start, convention)?.id, 'adult');
    });

    test('a toddler is a child', () {
      expect(categoryFor('2023-01-01', start, convention)?.id, 'child');
    });

    test('without a birth date, or with no age rules, there is no derived category', () {
      expect(categoryFor(null, start, convention), isNull);
      expect(
        categoryFor('2008-07-04', start, const [
          EventCategory(id: 'v', name: 'VIP'),
        ]),
        isNull,
      );
    });

    test('a rule with both bounds keeps to them', () {
      const teen = [
        EventCategory(id: 'teen', name: 'Teen', minAge: 13, maxAge: 17),
      ];
      expect(categoryFor('2012-07-03', start, teen)?.id, 'teen');
      expect(categoryFor('2014-07-03', start, teen), isNull);
    });
  });

  group('categoriesOf', () {
    test('reads the event setting, ignoring anything malformed', () {
      final categories = categoriesOf({
        'categories': [
          {'id': 'child', 'name': 'Child', 'maxAge': 17, 'isChild': true},
          {'id': 'adult', 'name': 'Adult', 'minAge': 18},
          {'name': 'No ID'},
          'junk',
        ],
      });
      expect(categories.map((c) => c.id), ['child', 'adult']);
      expect(categories.first.isChild, isTrue);
      expect(categories.first.hasAgeRule, isTrue);
      expect(categoriesOf(const {}), isEmpty);
    });

    test('round-trips through the stored shape', () {
      const c = EventCategory(id: 'teen', name: 'Teen', minAge: 13, maxAge: 17);
      expect(EventCategory.fromMap(c.toMap()), c);
    });
  });
}
