import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/phone.dart';

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
    this.phone = '',
    this.answers = const {},
    this.privateAnswers = const {},
    this.original,
  });

  /// Someone already saved, as loaded for editing (Spec #186 Req 26).
  factory PersonDraft.existing(PersonDraft loaded) => PersonDraft(
    id: loaded.id,
    name: loaded.name,
    isChild: loaded.isChild,
    birthDate: loaded.birthDate,
    email: loaded.email,
    phone: loaded.phone,
    answers: loaded.answers,
    privateAnswers: loaded.privateAnswers,
    original: loaded,
  );

  /// Fixed when the card is made, so a retried save never duplicates them.
  final String id;
  final String name;
  final bool isChild;

  /// A child's birth date, `YYYY-MM-DD`; it sets the age band.
  final String? birthDate;

  /// An adult's email, kept in private details for account linking.
  final String email;

  /// An adult's phone number as typed; saved in E.164 for account linking
  /// (Spec #233 Req 13).
  final String phone;

  /// Standard custom field answers, by field ID.
  final Map<String, Object?> answers;

  /// Private custom field answers, by field ID.
  final Map<String, Object?> privateAnswers;

  /// As saved, for someone being edited; null for someone new.
  final PersonDraft? original;

  bool get isExisting => original != null;

  /// Differs from what was saved; someone new always counts.
  bool get isChanged {
    final o = original;
    return o == null ||
        o.name != name ||
        o.isChild != isChild ||
        o.birthDate != birthDate ||
        o.email != email ||
        o.phone != phone ||
        !mapEquals(o.answers, answers) ||
        !mapEquals(o.privateAnswers, privateAnswers);
  }

  PersonDraft copyWith({
    String? name,
    bool? isChild,
    String? birthDate,
    bool clearBirthDate = false,
    String? email,
    String? phone,
    Map<String, Object?>? answers,
    Map<String, Object?>? privateAnswers,
  }) => PersonDraft(
    id: id,
    name: name ?? this.name,
    isChild: isChild ?? this.isChild,
    birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
    email: email ?? this.email,
    phone: phone ?? this.phone,
    answers: answers ?? this.answers,
    privateAnswers: privateAnswers ?? this.privateAnswers,
    original: original,
  );

  /// Nothing typed or chosen.
  bool get isEmpty =>
      name.trim().isEmpty &&
      birthDate == null &&
      email.trim().isEmpty &&
      phone.trim().isEmpty &&
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
    this.editing = false,
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

  /// Changing an existing group's answers and people ("Edit answers",
  /// Req 26), where nobody new is needed.
  final bool editing;
  final List<PersonDraft> people;

  /// The people to save: cards left completely empty are ignored, not an
  /// error (Req 31), and so is anyone being edited who did not change.
  List<PersonDraft> get toSave => [
    for (final p in people)
      if (p.isExisting ? p.isChanged : !p.isEmpty) p,
  ];

  bool get canAddPerson => people.length < maxPeople;

  GroupDraft copyWith({
    String? groupName,
    Map<String, Object?>? groupAnswers,
    Map<String, Object?>? groupPrivateAnswers,
    List<PersonDraft>? people,
  }) => GroupDraft(
    groupId: groupId,
    isNewGroup: isNewGroup,
    groupName: groupName ?? this.groupName,
    groupAnswers: groupAnswers ?? this.groupAnswers,
    groupPrivateAnswers: groupPrivateAnswers ?? this.groupPrivateAnswers,
    editing: editing,
    people: people ?? this.people,
  );

  GroupDraft _withPeople(List<PersonDraft> people) => copyWith(people: people);

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
  /// adult keeps only an email and phone, a child only a birth date, which
  /// sets their category by the event's age rules, counted on [eventStart]
  /// (Req 28). A phone typed without a prefix is read in [phoneCountry].
  /// Filter tags are worked out when saving, from the field definitions.
  List<PersonRecord> records({
    required String eventId,
    required String? createdBy,
    required List<EventCategory> categories,
    required DateTime eventStart,
    PhoneCountry phoneCountry = PhoneCountry.us,
  }) => [
    for (final p in toSave)
      _record(p, eventId, createdBy, categories, eventStart, phoneCountry),
  ];

  /// Whether [p]'s card shows a phone: adults, and anyone already saved, so
  /// a loaded number is never lost.
  static bool _keepsContact(PersonDraft p) => !p.isChild || p.isExisting;

  PersonRecord _record(
    PersonDraft p,
    String eventId,
    String? createdBy,
    List<EventCategory> categories,
    DateTime eventStart,
    PhoneCountry phoneCountry,
  ) {
    // Someone new keeps only what their card shows: a child's birth date
    // or an adult's email. Someone edited keeps what was loaded too, so a
    // hidden birth date or imported email is never lost.
    final birthDate = p.isChild || p.isExisting ? p.birthDate : null;
    final trimmed = p.email.trim();
    final email = trimmed.isEmpty || !_keepsContact(p) ? null : trimmed;
    final typedPhone = p.phone.trim();
    final phone = typedPhone.isEmpty || !_keepsContact(p)
        ? null
        : normalisePhone(typedPhone, phoneCountry);
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
        birthDate != null ||
        email != null ||
        phone != null ||
        privateFields.isNotEmpty;
    return PersonRecord(
      existing: p.isExisting,
      person,
      hasPrivate
          ? ParticipantPrivate(
              birthDate: birthDate,
              email: email,
              phone: phone,
              fields: privateFields,
            )
          : null,
    );
  }

  /// What stops a save: a missing group name, no named person, a person
  /// without a name, a phone number that is not whole (Spec #233 Req 13),
  /// and required answers left out (Req 29, 31). Only questions the viewer
  /// can see are checked, private ones with [readsPrivate].
  GroupDraftCheck check(
    List<CustomField> fields, {
    required bool readsPrivate,
    PhoneCountry phoneCountry = PhoneCountry.us,
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
      noPeople: !editing && toSave.isEmpty,
      groupMissing: problems(
        FieldScope.group,
        groupAnswers,
        groupPrivateAnswers,
      ),
      people: {
        for (final p in toSave)
          p.id: PersonCheck(
            nameMissing: p.name.trim().isEmpty,
            phoneInvalid:
                _keepsContact(p) &&
                p.phone.trim().isNotEmpty &&
                normalisePhone(p.phone, phoneCountry) == null,
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
  const PersonRecord(this.person, this.private, {this.existing = false});

  final ParticipantModel person;
  final ParticipantPrivate? private;

  /// Already saved: only what the group screen edits is updated.
  final bool existing;
}

/// What one person still needs before saving.
@immutable
class PersonCheck {
  const PersonCheck({
    this.nameMissing = false,
    this.phoneInvalid = false,
    this.missing = const {},
  });

  final bool nameMissing;

  /// A phone number was typed that is not a whole number.
  final bool phoneInvalid;

  /// Field IDs whose answers are missing or not allowed.
  final Set<String> missing;

  bool get ok => !nameMissing && !phoneInvalid && missing.isEmpty;
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
