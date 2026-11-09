import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/import_mapping.dart';

/// Req 44: reading an export's columns, and guessing what each one is, so
/// mapping is mostly confirming. The server checks the rows themselves.
void main() {
  group('previewCsv', () {
    test('gives the header, the first rows and how many there are', () {
      final preview = previewCsv(
        'Name,"Family, last"\nAna,"Shah"\n"Bo ""B""",Patel\n\n',
      );
      expect(preview.header, ['Name', 'Family, last']);
      expect(preview.rows, [
        ['Ana', 'Shah'],
        ['Bo "B"', 'Patel'],
      ]);
      expect(preview.rowCount, 2);
    });

    test('keeps at most a few rows to show', () {
      final text = ['A', for (var i = 0; i < 50; i++) '$i'].join('\n');
      final preview = previewCsv(text, rows: 5);
      expect(preview.rows, hasLength(5));
      expect(preview.rowCount, 50);
    });

    test('an empty or unreadable file has nothing to map', () {
      expect(() => previewCsv(''), throwsFormatException);
      expect(() => previewCsv('A\n"open'), throwsFormatException);
    });
  });

  group('guessTarget', () {
    const fields = [
      CustomField(id: 'diet', label: 'Diet', type: FieldType.singleChoice),
      CustomField(id: 'tshirt', label: 'T-shirt size', type: FieldType.text),
    ];
    String guess(String header) => guessTarget(header, fields);

    test('recognises the usual names for each column', () {
      expect(guess('Full name'), 'name');
      expect(guess('Name'), 'name');
      expect(guess('Household'), 'group');
      expect(guess('Team'), 'group');
      expect(guess('Registration ID'), 'externalId');
      expect(guess('External ID'), 'externalId');
      expect(guess('Date of birth'), 'birthDate');
      expect(guess('DOB'), 'birthDate');
      expect(guess('Age'), 'age');
      expect(guess('E-mail'), 'email');
      expect(guess('Category'), 'category');
      expect(guess('Is child'), 'isChild');
    });

    test("uses the event's own word for a group", () {
      expect(
        guessTarget(
          'Household name',
          fields,
          words: const {
            'group': ['Household name', 'Households'],
          },
        ),
        'group',
      );
    });

    test('matches a custom field by its label, ignoring case and spaces', () {
      expect(guess('diet'), 'field:diet');
      expect(guess(' T-Shirt Size '), 'field:tshirt');
    });

    test('anything else is ignored until someone maps it', () {
      expect(guess('Shoe size'), 'ignore');
    });

    test('guesses each target once, ignoring later columns that match', () {
      expect(guessTargets(['Name', 'Team', 'Name'], fields), [
        'name',
        'group',
        'ignore',
      ]);
    });
  });

  test('a mapping needs a name column', () {
    expect(mappingProblem(['ignore', 'group']), MappingProblem.nameNotMapped);
    expect(mappingProblem(['name', 'group']), isNull);
  });
}
