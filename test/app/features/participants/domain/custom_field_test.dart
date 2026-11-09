import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';

/// Req 41 (GE-04, GAP-WED-14): custom fields, their answers, and the tags
/// the roster filters by.
void main() {
  CustomField field(
    FieldType type, {
    String id = 'f',
    List<String> options = const [],
    bool required = false,
    FieldVisibility visibility = FieldVisibility.standard,
  }) => CustomField(
    id: id,
    label: 'Field',
    type: type,
    options: options,
    required: required,
    visibility: visibility,
  );

  group('checking an answer', () {
    test('required fields need an answer', () {
      final diet = field(FieldType.text, required: true);
      expect(checkAnswer(diet, null), AnswerProblem.required);
      expect(checkAnswer(diet, '  '), AnswerProblem.required);
      expect(checkAnswer(diet, 'Jain'), isNull);
      expect(checkAnswer(field(FieldType.text), null), isNull);
    });

    test('each type takes its own kind of answer', () {
      expect(checkAnswer(field(FieldType.number), 12), isNull);
      expect(checkAnswer(field(FieldType.number), 'twelve'), AnswerProblem.wrongType);
      expect(checkAnswer(field(FieldType.date), '2026-07-03'), isNull);
      expect(checkAnswer(field(FieldType.date), '3 July'), AnswerProblem.wrongType);
      expect(checkAnswer(field(FieldType.yesNo), true), isNull);
      expect(checkAnswer(field(FieldType.yesNo), 'yes'), AnswerProblem.wrongType);
      expect(checkAnswer(field(FieldType.text), 'x' * 501), AnswerProblem.tooLong);
    });

    test('choices must be among the options', () {
      final meal = field(FieldType.singleChoice, options: ['Fish', 'Veg']);
      expect(checkAnswer(meal, 'Veg'), isNull);
      expect(checkAnswer(meal, 'Beef'), AnswerProblem.notAnOption);
      final extras = field(FieldType.multiChoice, options: ['A', 'B']);
      expect(checkAnswer(extras, ['A', 'B']), isNull);
      expect(checkAnswer(extras, ['A', 'C']), AnswerProblem.notAnOption);
      expect(
        checkAnswer(field(FieldType.multiChoice, options: ['A'], required: true), <String>[]),
        AnswerProblem.required,
      );
    });
  });

  group('filter tags', () {
    final fields = [
      field(FieldType.singleChoice, id: 'diet', options: ['Jain', 'Veg']),
      field(FieldType.multiChoice, id: 'extras', options: ['Kids', 'Yoga']),
      field(FieldType.yesNo, id: 'parking'),
      field(FieldType.text, id: 'notes'),
      field(
        FieldType.singleChoice,
        id: 'allergy',
        options: ['Nuts'],
        visibility: FieldVisibility.private,
      ),
    ];

    test('come from standard choice and yes/no answers only', () {
      final tags = filterTagsFor(fields, {
        'diet': 'Jain',
        'extras': ['Kids', 'Yoga'],
        'parking': false,
        'notes': 'Late arrival',
        'allergy': 'Nuts',
      });
      expect(tags, ['diet=Jain', 'extras=Kids', 'extras=Yoga', 'parking=no']);
    });

    test('a tag names a field and a value', () {
      expect(filterTag('parking', true), 'parking=yes');
      expect(filterTag('diet', 'Veg'), 'diet=Veg');
    });

    test('only standard choice and yes/no fields can filter the roster', () {
      expect(fields.where((f) => f.filters).map((f) => f.id), [
        'diet',
        'extras',
        'parking',
      ]);
    });
  });

  test('round-trips through Firestore, defaulting what is missing', () {
    final f = CustomField.fromFirestore('diet', const {
      'label': 'Diet',
      'type': 'singleChoice',
      'options': ['Jain', 'Veg'],
      'required': true,
      'scope': 'group',
      'visibility': 'private',
      'order': 2,
    });
    expect(f.scope, FieldScope.group);
    expect(f.visibility, FieldVisibility.private);
    expect(CustomField.fromFirestore('diet', f.toMap()), f);
    final odd = CustomField.fromFirestore('x', const {'label': 'X', 'type': 'hologram'});
    expect(odd.type, FieldType.text);
    expect(odd.scope, FieldScope.participant);
  });
}
