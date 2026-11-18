import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

/// A new document ID, picked before saving so a retry writes the same
/// document again instead of a second one.
String newRecordId() {
  final random = Random.secure();
  return List.generate(
    20,
    (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)],
  ).join();
}

/// One person on the group screen, before saving (Spec #186 Req 28).
@immutable
class PersonDraft {
  const PersonDraft({
    required this.id,
    this.name = '',
    this.isChild = false,
    this.birthDate,
    this.email = '',
    this.answers = const {},
    this.privateAnswers = const {},
  });

  /// Fixed when the card is made, so a retried save never duplicates them.
  final String id;
  final String name;
  final bool isChild;

  /// A child's birth date, `YYYY-MM-DD`; it sets the age band.
  final String? birthDate;

  /// An adult's email, kept in private details for account linking.
  final String email;

  /// Standard custom field answers, by field ID.
  final Map<String, Object?> answers;

  /// Private custom field answers, by field ID.
  final Map<String, Object?> privateAnswers;

  PersonDraft copyWith({
    String? name,
    bool? isChild,
    String? birthDate,
    bool clearBirthDate = false,
    String? email,
    Map<String, Object?>? answers,
    Map<String, Object?>? privateAnswers,
  }) => PersonDraft(
    id: id,
    name: name ?? this.name,
    isChild: isChild ?? this.isChild,
    birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
    email: email ?? this.email,
    answers: answers ?? this.answers,
    privateAnswers: privateAnswers ?? this.privateAnswers,
  );

  /// Nothing typed or chosen.
  bool get isEmpty =>
      name.trim().isEmpty &&
      birthDate == null &&
      email.trim().isEmpty &&
      answers.isEmpty &&
      privateAnswers.isEmpty;
}

/// The whole group screen before saving: the group and its people
/// (Technical Decision 4).
@immutable
class GroupDraft {
  const GroupDraft({
    required this.groupId,
    required this.isNewGroup,
    required this.people,
    this.groupName = '',
    this.groupAnswers = const {},
    this.groupPrivateAnswers = const {},
  });

  /// Two empty people, ready to fill in (Req 31).
  factory GroupDraft.start({
    required String groupId,
    required bool isNewGroup,
    required String Function() newId,
    String groupName = '',
    Map<String, Object?> groupAnswers = const {},
    Map<String, Object?> groupPrivateAnswers = const {},
  }) => GroupDraft(
    groupId: groupId,
    isNewGroup: isNewGroup,
    groupName: groupName,
    groupAnswers: groupAnswers,
    groupPrivateAnswers: groupPrivateAnswers,
    people: [
      PersonDraft(id: newId()),
      PersonDraft(id: newId()),
    ],
  );

  /// At most this many people are saved at a time (Req 31).
  static const maxPeople = 20;

  /// Fixed when the screen opens: a new group's ID is picked then.
  final String groupId;
  final bool isNewGroup;
  final String groupName;

  /// The group's own answers to group-scope fields, standard and private.
  final Map<String, Object?> groupAnswers;
  final Map<String, Object?> groupPrivateAnswers;
  final List<PersonDraft> people;

  /// The people to save: cards left completely empty are ignored, not an
  /// error (Req 31).
  List<PersonDraft> get toSave => [
    for (final p in people)
      if (!p.isEmpty) p,
  ];

  bool get canAddPerson => people.length < maxPeople;

  GroupDraft _withPeople(List<PersonDraft> people) => GroupDraft(
    groupId: groupId,
    isNewGroup: isNewGroup,
    groupName: groupName,
    groupAnswers: groupAnswers,
    groupPrivateAnswers: groupPrivateAnswers,
    people: people,
  );

  /// Another empty card, unless there are [maxPeople] already.
  GroupDraft addPerson(String id) =>
      canAddPerson ? _withPeople([...people, PersonDraft(id: id)]) : this;

  GroupDraft removePerson(String id) => _withPeople([
    for (final p in people)
      if (p.id != id) p,
  ]);

  /// "Same answers as" the person before [id] (Req 30): every custom field
  /// answer the viewer can see, private ones only when [readsPrivate].
  /// Never the name, adult or child, birth date or email.
  GroupDraft copyFromPrevious(String id, {required bool readsPrivate}) {
    final index = people.indexWhere((p) => p.id == id);
    if (index < 1) return this;
    final from = people[index - 1];
    final to = people[index].copyWith(
      answers: {...from.answers},
      privateAnswers: readsPrivate ? {...from.privateAnswers} : null,
    );
    return _withPeople([...people]..[index] = to);
  }

  /// The participants to write, worked out as the person form does: an
  /// adult keeps only an email, a child only a birth date, which sets their
  /// category by the event's age rules, counted on [eventStart] (Req 28).
  /// Filter tags are worked out when saving, from the field definitions.
  List<PersonRecord> records({
    required String eventId,
    required String? createdBy,
    required List<EventCategory> categories,
    required DateTime eventStart,
  }) => [
    for (final p in toSave)
      _record(p, eventId, createdBy, categories, eventStart),
  ];

  PersonRecord _record(
    PersonDraft p,
    String eventId,
    String? createdBy,
    List<EventCategory> categories,
    DateTime eventStart,
  ) {
    final birthDate = p.isChild ? p.birthDate : null;
    final email = p.isChild || p.email.trim().isEmpty ? null : p.email.trim();
    final derived = categoryFor(birthDate, eventStart, categories);
    final person = ParticipantModel(
      id: p.id,
      eventId: eventId,
      name: p.name.trim(),
      groupId: groupId,
      isChild: derived?.isChild ?? p.isChild,
      categoryId: derived?.id,
      createdBy: createdBy,
      fields: {...p.answers}..removeWhere((_, v) => v == null),
    );
    final privateFields = {...p.privateAnswers}
      ..removeWhere((_, v) => v == null);
    final hasPrivate =
        birthDate != null || email != null || privateFields.isNotEmpty;
    return PersonRecord(
      person,
      hasPrivate
          ? ParticipantPrivate(
              birthDate: birthDate,
              email: email,
              fields: privateFields,
            )
          : null,
    );
  }

  /// What stops a save: a missing group name, no named person, a person
  /// without a name, and required answers left out (Req 29, 31). Only
  /// questions the viewer can see are checked, private ones with
  /// [readsPrivate].
  GroupDraftCheck check(
    List<CustomField> fields, {
    required bool readsPrivate,
  }) {
    Set<String> problems(
      FieldScope scope,
      Map<String, Object?> standard,
      Map<String, Object?> private,
    ) => {
      for (final f in fields)
        if (f.scope == scope && (readsPrivate || !f.isPrivate))
          if (checkAnswer(f, (f.isPrivate ? private : standard)[f.id]) != null)
            f.id,
    };

    return GroupDraftCheck(
      groupNameMissing: isNewGroup && groupName.trim().isEmpty,
      noPeople: toSave.isEmpty,
      groupMissing: problems(
        FieldScope.group,
        groupAnswers,
        groupPrivateAnswers,
      ),
      people: {
        for (final p in toSave)
          p.id: PersonCheck(
            nameMissing: p.name.trim().isEmpty,
            missing: problems(
              FieldScope.participant,
              p.answers,
              p.privateAnswers,
            ),
          ),
      },
    );
  }
}

/// One person as saved: the participant and, when there is anything
/// private, their private details.
@immutable
class PersonRecord {
  const PersonRecord(this.person, this.private);

  final ParticipantModel person;
  final ParticipantPrivate? private;
}

/// What one person still needs before saving.
@immutable
class PersonCheck {
  const PersonCheck({this.nameMissing = false, this.missing = const {}});

  final bool nameMissing;

  /// Field IDs whose answers are missing or not allowed.
  final Set<String> missing;

  bool get ok => !nameMissing && missing.isEmpty;
}

/// What a [GroupDraft] still needs before saving.
@immutable
class GroupDraftCheck {
  const GroupDraftCheck({
    this.groupNameMissing = false,
    this.noPeople = false,
    this.groupMissing = const {},
    this.people = const {},
  });

  final bool groupNameMissing;

  /// No named person to save (Req 31: "Add at least one person").
  final bool noPeople;

  /// The group's own required answers that are missing.
  final Set<String> groupMissing;

  /// By person ID, for every card that will be saved.
  final Map<String, PersonCheck> people;

  /// How many answers are missing, for the save bar.
  int get missingCount =>
      groupMissing.length +
      people.values.fold(0, (sum, p) => sum + p.missing.length);

  bool get ok =>
      !groupNameMissing &&
      !noPeople &&
      groupMissing.isEmpty &&
      people.values.every((p) => p.ok);
}
