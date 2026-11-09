import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

/// #76 (Req 41): custom fields on guests. The rules half is
/// `functions/test/fields.test.ts`.
void main() {
  test('GAP-WED-14 each guest has a meal choice and a private allergy, and the '
      'list filters by the choice', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ParticipantRepository(firestore: firestore);
    const choice = CustomField(
      id: 'choice',
      label: 'Dinner',
      type: FieldType.singleChoice,
      options: ['Fish', 'Veg'],
      required: true,
    );
    const allergy = CustomField(
      id: 'allergy',
      label: 'Allergy',
      type: FieldType.text,
      visibility: FieldVisibility.private,
    );
    for (final (id, pick, note) in [
      ('g1', 'Fish', 'None'),
      ('g2', 'Veg', 'Nuts'),
      ('g3', 'Veg', null),
    ]) {
      expect(checkAnswer(choice, pick), isNull);
      await repo.save(
        ParticipantModel(
          id: id,
          eventId: 'w',
          name: 'Guest $id',
          createdBy: 'couple',
          fields: {'choice': pick},
        ),
        privateDetails: ParticipantPrivate(
          fields: {'allergy': ?note},
        ),
        definitions: const [choice, allergy],
      );
    }
    final veg = await repo.fetchPage('w', const RosterQuery(tag: 'choice=Veg'));
    expect(veg.items.map((p) => p.id), ['g2', 'g3']);
    // The allergy is never on the guest record the list reads.
    for (final p in veg.items) {
      expect(p.fields, isNot(contains('allergy')));
    }
    expect((await repo.readPrivate('w', 'g2'))?.fields['allergy'], 'Nuts');
    // A required choice cannot be left empty.
    expect(checkAnswer(choice, null), AnswerProblem.required);
  });
}
