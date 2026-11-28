import 'package:flutter/foundation.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/registration/domain/form_conditions.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';
import 'package:crewpoint_app/app/features/registration/domain/session_choices.dart';
import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

/// One by-sign-up session offered on the form (Spec #233 Req 17).
@immutable
class ChoiceSession {
  const ChoiceSession({
    required this.id,
    required this.title,
    required this.startAt,
    this.endAt,
  });

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
}

/// What `submitRegistration` decided (Req 25, 33): `submitted`, `pending`
/// or `waitlisted`, with the waitlist number.
@immutable
class SubmitResult {
  const SubmitResult({
    required this.registrationId,
    required this.status,
    this.waitlistPosition,
  });

  factory SubmitResult.fromMap(Map<String, Object?> data) => SubmitResult(
    registrationId: data['registrationId'] as String? ?? '',
    status: data['status'] as String? ?? 'submitted',
    waitlistPosition: (data['waitlistPosition'] as num?)?.toInt(),
  );

  final String registrationId;
  final String status;
  final int? waitlistPosition;

  bool get waitlisted => status == 'waitlisted';
}

/// What someone already registered may change (#244): everything before
/// the deadline, only contact details after it.
enum FormEditable { all, contact }

/// A registration the caller already has (Req 4).
@immutable
class ExistingRegistration {
  const ExistingRegistration({required this.status, this.waitlistPosition});

  final String status;
  final int? waitlistPosition;
}

/// One step of the form: the people, a section, the stays, the session
/// choices, the contact details, then the review (Req 17, 20).
@immutable
class FormStep {
  const FormStep(this.id, {this.section});

  final String id;

  /// The section this step asks, for `section:<id>` steps.
  final RegistrationSection? section;

  static const people = 'people';
  static const stay = 'stay';
  static const sessions = 'sessions';
  static const waivers = 'waivers';
  static const contact = 'contact';
  static const review = 'review';
}

/// Something to fix before Submit (Req 21): on which step, for which
/// person (none for the group or the contact), and what: a question ID or
/// `name`, `birthDate`, `age`, `departureAt`, `signUps`, `email`, `phone`,
/// `noPeople`, or a required waiver's ID on the waivers step.
@immutable
class FormProblem {
  const FormProblem(this.step, this.key, {this.person});

  final String step;
  final String key;
  final int? person;

  @override
  bool operator ==(Object other) =>
      other is FormProblem &&
      other.step == step &&
      other.key == key &&
      other.person == person;

  @override
  int get hashCode => Object.hash(step, key, person);

  @override
  String toString() => 'FormProblem($step, $key, person: $person)';
}

/// One person on the form, as typed.
@immutable
class PersonEntry {
  const PersonEntry({
    this.id,
    this.name = '',
    this.birthDate,
    this.age,
    this.answers = const {},
    this.arrivalAt,
    this.departureAt,
    this.signUps = const {},
    this.optOuts = const {},
    this.acceptWaivers = const {},
    this.waiverVersions = const {},
    this.photoConsent,
  });

  /// The participant this entry edits (#244); null for someone new.
  final String? id;

  final String name;

  /// `YYYY-MM-DD`; [age] instead when the event asks for age only.
  final String? birthDate;
  final int? age;

  /// Standard and private answers together, by question ID.
  final Map<String, Object?> answers;
  final DateTime? arrivalAt;
  final DateTime? departureAt;
  final Set<String> signUps;

  /// Sessions everyone attends that this person will miss (#244, B-03).
  final Set<String> optOuts;

  /// Waivers accepted for this person on this form (#246).
  final Set<String> acceptWaivers;

  /// The versions this person accepted before, from the server (#246).
  final Map<String, int> waiverVersions;

  /// Photos and videos of this person, yes or no; null while unanswered
  /// (Spec #233 Req 30, #247). A guardian answers for a child.
  final bool? photoConsent;

  PersonEntry copyWith({
    String? name,
    String? birthDate,
    int? age,
    Map<String, Object?>? answers,
    DateTime? arrivalAt,
    DateTime? departureAt,
    Set<String>? signUps,
    Set<String>? optOuts,
    Set<String>? acceptWaivers,
    bool? photoConsent,
    bool clearAge = false,
    bool clearArrival = false,
    bool clearDeparture = false,
  }) => PersonEntry(
    id: id,
    name: name ?? this.name,
    birthDate: birthDate ?? this.birthDate,
    age: clearAge ? null : age ?? this.age,
    answers: answers ?? this.answers,
    arrivalAt: clearArrival ? null : arrivalAt ?? this.arrivalAt,
    departureAt: clearDeparture ? null : departureAt ?? this.departureAt,
    signUps: signUps ?? this.signUps,
    optOuts: optOuts ?? this.optOuts,
    acceptWaivers: acceptWaivers ?? this.acceptWaivers,
    waiverVersions: waiverVersions,
    photoConsent: photoConsent ?? this.photoConsent,
  );
}

/// The whole form as typed. [submissionId] is made once per form, so a
/// repeated Submit is the same submission (Req 25, TD 4).
@immutable
class RegistrationDraft {
  const RegistrationDraft({
    required this.submissionId,
    this.people = const [],
    this.groupAnswers = const {},
    this.groupName = '',
    this.email = '',
    this.phone = '',
    this.consentEmail = false,
    this.consentSms = false,
  });

  final String submissionId;
  final List<PersonEntry> people;
  final Map<String, Object?> groupAnswers;
  final String groupName;
  final String email;
  final String phone;

  /// Consent to announcements by email and by SMS (Req 31, #246), apart
  /// from essential messages.
  final bool consentEmail;
  final bool consentSms;

  /// The draft as kept on the device and on the server (#243): plain JSON,
  /// times in milliseconds since the epoch.
  Map<String, Object?> toMap() => {
    'submissionId': submissionId,
    'groupName': groupName,
    'email': email,
    'phone': phone,
    'consentEmail': consentEmail,
    'consentSms': consentSms,
    'groupAnswers': groupAnswers,
    'people': [
      for (final p in people)
        {
          'id': p.id,
          'name': p.name,
          'birthDate': p.birthDate,
          'age': p.age,
          'answers': p.answers,
          'arrivalAt': p.arrivalAt?.millisecondsSinceEpoch,
          'departureAt': p.departureAt?.millisecondsSinceEpoch,
          'signUps': p.signUps.toList()..sort(),
          'optOuts': p.optOuts.toList()..sort(),
          'acceptWaivers': p.acceptWaivers.toList()..sort(),
          'waiverVersions': p.waiverVersions,
          'photoConsent': p.photoConsent,
        },
    ],
  };

  /// A draft from [toMap], or null when [raw] isn't one.
  static RegistrationDraft? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['submissionId'];
    final people = raw['people'];
    if (id is! String || id.isEmpty || people is! List) return null;
    DateTime? time(Object? v) => v is num
        ? DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true)
        : null;
    String text(Object? v) => v is String ? v : '';
    Map<String, Object?> answers(Object? v) =>
        v is Map ? {for (final e in v.entries) '${e.key}': e.value} : {};
    return RegistrationDraft(
      submissionId: id,
      groupName: text(raw['groupName']),
      email: text(raw['email']),
      phone: text(raw['phone']),
      consentEmail: raw['consentEmail'] == true,
      consentSms: raw['consentSms'] == true,
      groupAnswers: answers(raw['groupAnswers']),
      people: [
        for (final p in people)
          if (p is Map)
            PersonEntry(
              id: p['id'] is String ? p['id'] as String : null,
              name: text(p['name']),
              birthDate: p['birthDate'] is String
                  ? p['birthDate'] as String
                  : null,
              age: (p['age'] as num?)?.toInt(),
              answers: answers(p['answers']),
              arrivalAt: time(p['arrivalAt']),
              departureAt: time(p['departureAt']),
              signUps: {
                for (final s in (p['signUps'] as List?) ?? const [])
                  if (s is String) s,
              },
              optOuts: {
                for (final s in (p['optOuts'] as List?) ?? const [])
                  if (s is String) s,
              },
              acceptWaivers: {
                for (final s in (p['acceptWaivers'] as List?) ?? const [])
                  if (s is String) s,
              },
              waiverVersions: {
                if (p['waiverVersions'] is Map)
                  for (final e in (p['waiverVersions'] as Map).entries)
                    if (e.value is num) '${e.key}': (e.value as num).toInt(),
              },
              photoConsent: p['photoConsent'] is bool
                  ? p['photoConsent'] as bool
                  : null,
            ),
      ],
    );
  }

  factory RegistrationDraft.fromMap(Map<String, Object?> map) => tryParse(map)!;

  RegistrationDraft copyWith({
    List<PersonEntry>? people,
    Map<String, Object?>? groupAnswers,
    String? groupName,
    String? email,
    String? phone,
    bool? consentEmail,
    bool? consentSms,
  }) => RegistrationDraft(
    submissionId: submissionId,
    people: people ?? this.people,
    groupAnswers: groupAnswers ?? this.groupAnswers,
    groupName: groupName ?? this.groupName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    consentEmail: consentEmail ?? this.consentEmail,
    consentSms: consentSms ?? this.consentSms,
  );
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool _empty(Object? v) =>
    v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

/// What the registration form asks, from `getRegistrationForm` (Spec #233
/// Req 16-18, 20; #242), and the checks made on Submit (Req 21). The
/// server makes the same checks again.
@immutable
class RegistrationFormSpec {
  const RegistrationFormSpec({
    required this.slug,
    required this.title,
    required this.timeZone,
    this.startDate,
    this.endDate,
    this.dateOnly = false,
    this.deadline,
    this.review = false,
    this.blocks = const {},
    this.sections = const [],
    this.conditions = const {},
    this.categories = const [],
    this.fields = const [],
    this.choices = const [],
    this.labels = const {},
    this.registration,
    this.serverDraft,
    this.serverDraftSavedAt,
    this.current,
    this.editable,
    this.attending = const [],
    this.contactLine,
    this.waivers = const [],
    this.completing = false,
  });

  factory RegistrationFormSpec.fromMap(Map<String, Object?> data) {
    DateTime? time(Object? raw) => raw is num
        ? DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true)
        : null;
    final blocks = data['blocks'];
    final conditions = data['conditions'];
    final existing = data['registration'];
    final draft = data['draft'];
    return RegistrationFormSpec(
      slug: data['slug'] as String? ?? '',
      title: data['title'] as String? ?? '',
      timeZone: data['timeZone'] as String? ?? 'UTC',
      startDate: time(data['startDate']),
      endDate: time(data['endDate']),
      dateOnly: data['dateOnly'] == true,
      deadline: time(data['deadline']),
      review: data['review'] == true,
      blocks: {
        if (blocks is Map)
          for (final b in RegistrationBlock.values)
            if (blocks[b.name] == true) b,
      },
      sections: [
        for (final raw in (data['sections'] as List?) ?? const [])
          ?RegistrationSection.tryParse(raw),
      ],
      conditions: {
        if (conditions is Map)
          for (final e in conditions.entries)
            if (e.key is String && FieldCondition.tryParse(e.value) != null)
              e.key as String: FieldCondition.tryParse(e.value)!,
      },
      categories: [
        for (final raw in (data['categories'] as List?) ?? const [])
          ?EventCategory.tryParse(raw),
      ],
      fields: [
        for (final raw in (data['fields'] as List?) ?? const [])
          if (raw is Map && raw['id'] is String)
            CustomField.fromFirestore(
              raw['id'] as String,
              Map<String, dynamic>.from(raw),
            ),
      ],
      choices: [
        for (final choice in (data['choices'] as List?) ?? const [])
          [
            for (final s in (choice as List?) ?? const [])
              if (s is Map && s['id'] is String && time(s['startAt']) != null)
                ChoiceSession(
                  id: s['id'] as String,
                  title: s['title'] as String? ?? '',
                  startAt: time(s['startAt'])!,
                  endAt: time(s['endAt']),
                ),
          ],
      ],
      labels: data['labels'] is Map
          ? Map<String, dynamic>.from(data['labels'] as Map)
          : const {},
      registration: existing is Map && existing['status'] is String
          ? ExistingRegistration(
              status: existing['status'] as String,
              waitlistPosition: (existing['waitlistPosition'] as num?)?.toInt(),
            )
          : null,
      serverDraft: draft is Map
          ? RegistrationDraft.tryParse(draft['data'])
          : null,
      serverDraftSavedAt: draft is Map ? time(draft['savedAt']) : null,
      current: data['current'] is Map
          ? RegistrationDraft.tryParse({
              ...Map<String, Object?>.from(data['current']! as Map),
              'submissionId': 'edit',
              'email': (data['current']! as Map)['email'] ?? '',
              'phone': (data['current']! as Map)['phone'] ?? '',
            })
          : null,
      editable: switch (data['editable']) {
        'all' => FormEditable.all,
        'contact' => FormEditable.contact,
        _ => null,
      },
      attending: [
        for (final s in (data['attending'] as List?) ?? const [])
          if (s is Map && s['id'] is String && time(s['startAt']) != null)
            ChoiceSession(
              id: s['id'] as String,
              title: s['title'] as String? ?? '',
              startAt: time(s['startAt'])!,
              endAt: time(s['endAt']),
            ),
      ],
      contactLine: LocalText.tryParse(data['contactLine']),
      waivers: [
        for (final raw in (data['waivers'] as List?) ?? const [])
          ?Waiver.tryParse(raw),
      ],
      completing: data['completing'] == true,
    );
  }

  final String slug;
  final String title;
  final String timeZone;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool dateOnly;
  final DateTime? deadline;
  final bool review;
  final Set<RegistrationBlock> blocks;
  final List<RegistrationSection> sections;
  final Map<String, FieldCondition> conditions;
  final List<EventCategory> categories;
  final List<CustomField> fields;
  final List<List<ChoiceSession>> choices;
  final Map<String, dynamic> labels;
  final ExistingRegistration? registration;

  /// The server's copy of the form as typed (#243), and when the device
  /// that typed it saved it.
  final RegistrationDraft? serverDraft;
  final DateTime? serverDraftSavedAt;

  /// The caller's registration to edit (#244), people with their IDs.
  final RegistrationDraft? current;
  final FormEditable? editable;

  /// Sessions everyone attends, which a person may opt out of (B-03).
  final List<ChoiceSession> attending;

  /// How to reach the organizer, for closed pages (Req 35).
  final LocalText? contactLine;

  /// The event's waivers (#246), with the waivers block on.
  final List<Waiver> waivers;

  /// Completing a group the organizer added (#249): [current] holds its
  /// people, sent as a new registration with `completeRegistrationId`.
  final bool completing;

  bool get editing => current != null && !completing;

  bool has(RegistrationBlock block) => blocks.contains(block);

  /// The questions a section asks, in the section's order.
  List<CustomField> questionsIn(RegistrationSection section) => [
    for (final id in section.fieldIds)
      ?fields.where((f) => f.id == id).firstOrNull,
  ];

  /// The form's steps (Req 17, 20): People, each section, Stay, Session
  /// choices and Contact when switched on, then Review.
  List<FormStep> get steps => editable == FormEditable.contact
      ? const [FormStep(FormStep.contact), FormStep(FormStep.review)]
      : [
          const FormStep(FormStep.people),
          for (final s in sections)
            if (questionsIn(s).isNotEmpty)
              FormStep('section:${s.id}', section: s),
          if (has(RegistrationBlock.stay)) const FormStep(FormStep.stay),
          if (has(RegistrationBlock.sessionChoices) &&
              (choices.isNotEmpty || attending.isNotEmpty))
            const FormStep(FormStep.sessions),
          if (has(RegistrationBlock.waivers) && waivers.isNotEmpty)
            const FormStep(FormStep.waivers),
          if (has(RegistrationBlock.contact)) const FormStep(FormStep.contact),
          const FormStep(FormStep.review),
        ];

  /// [person]'s category on the event's first day, from their birth date,
  /// or their age when the event asks for age only; null while unknown.
  EventCategory? categoryOf(PersonEntry person) {
    final on = startDate ?? DateTime.now();
    if (has(RegistrationBlock.ageOnly)) {
      final age = person.age;
      if (age == null) return null;
      for (final c in categories) {
        if (c.hasAgeRule && c.fits(age)) return c;
      }
      return null;
    }
    return categoryFor(person.birthDate, on, categories);
  }

  /// Whether [field] is asked of [person] (or of the group, when null).
  bool shows(
    CustomField field,
    RegistrationDraft draft, {
    PersonEntry? person,
  }) => isShown(
    conditions[field.id],
    categoryId: person == null ? null : categoryOf(person)?.id,
    answers: {...draft.groupAnswers, ...?person?.answers},
  );

  /// The waivers that apply to [person] and that their earlier acceptance
  /// does not cover (Req 26, 28): what the waivers step asks of them.
  List<Waiver> waiversFor(PersonEntry person) => [
    if (has(RegistrationBlock.waivers))
      for (final w in waivers)
        if (waiverApplies(
              w.appliesTo,
              categoryId: categoryOf(person)?.id,
              signUps: person.signUps,
            ) &&
            !acceptanceStatus(
              version: w.version,
              requireLatest: w.requireLatest,
              accepted: person.waiverVersions[w.id],
            ).counts)
          w,
  ];

  /// Everything to fix before Submit, in step order (Req 21).
  List<FormProblem> problems(RegistrationDraft draft) {
    final found = <FormProblem>[];
    final people = draft.people;
    if (people.isEmpty) {
      found.add(const FormProblem(FormStep.people, 'noPeople'));
    }
    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      if (p.name.trim().isEmpty) {
        found.add(FormProblem(FormStep.people, 'name', person: i));
      }
      if (has(RegistrationBlock.people)) {
        if (has(RegistrationBlock.ageOnly)) {
          if (p.age == null || p.age! < 0 || p.age! > 130) {
            found.add(FormProblem(FormStep.people, 'age', person: i));
          }
        } else if (ageOn(p.birthDate, startDate ?? DateTime.now()) == null) {
          found.add(FormProblem(FormStep.people, 'birthDate', person: i));
        }
      }
    }
    for (final step in steps.where((s) => s.section != null)) {
      for (final q in questionsIn(step.section!)) {
        if (!q.required) continue;
        if (q.scope == FieldScope.group) {
          if (shows(q, draft) && _empty(draft.groupAnswers[q.id])) {
            found.add(FormProblem(step.id, q.id));
          }
          continue;
        }
        for (var i = 0; i < people.length; i++) {
          if (shows(q, draft, person: people[i]) &&
              _empty(people[i].answers[q.id])) {
            found.add(FormProblem(step.id, q.id, person: i));
          }
        }
      }
    }
    if (has(RegistrationBlock.stay)) {
      for (var i = 0; i < people.length; i++) {
        final (a, d) = (people[i].arrivalAt, people[i].departureAt);
        if (a != null && d != null && d.isBefore(a)) {
          found.add(FormProblem(FormStep.stay, 'departureAt', person: i));
        }
      }
    }
    if (has(RegistrationBlock.sessionChoices)) {
      final ids = [
        for (final c in choices) [for (final s in c) s.id],
      ];
      for (var i = 0; i < people.length; i++) {
        if (!validSignUps(ids, people[i].signUps)) {
          found.add(FormProblem(FormStep.sessions, 'signUps', person: i));
        }
      }
    }
    // A required waiver blocks Submit until accepted (Req 29).
    for (var i = 0; i < people.length; i++) {
      for (final w in waiversFor(people[i])) {
        if (w.required && !people[i].acceptWaivers.contains(w.id)) {
          found.add(FormProblem(FormStep.waivers, w.id, person: i));
        }
      }
    }
    if (has(RegistrationBlock.contact) &&
        !_email.hasMatch(draft.email.trim())) {
      found.add(const FormProblem(FormStep.contact, 'email'));
    }
    return found;
  }

  /// What `submitRegistration` is sent: answers a condition hides are left
  /// out, and blocks that are off send nothing.
  Map<String, Object?> toSubmitMap(RegistrationDraft draft) {
    final groupQuestions = fields.where((f) => f.scope == FieldScope.group);
    final personQuestions = fields.where(
      (f) => f.scope == FieldScope.participant,
    );
    return {
      'slug': slug,
      'submissionId': draft.submissionId,
      'groupName': draft.groupName.trim(),
      'groupAnswers': {
        for (final q in groupQuestions)
          if (shows(q, draft) && !_empty(draft.groupAnswers[q.id]))
            q.id: draft.groupAnswers[q.id],
      },
      if (has(RegistrationBlock.contact))
        'contact': {
          if (draft.email.trim().isNotEmpty) 'email': draft.email.trim(),
          if (draft.phone.trim().isNotEmpty) 'phone': draft.phone.trim(),
        },
      if (has(RegistrationBlock.contact) && !editing)
        'consent': {'email': draft.consentEmail, 'sms': draft.consentSms},
      'people': [
        for (final p in draft.people)
          {
            'id': ?p.id,
            'name': p.name.trim(),
            if (has(RegistrationBlock.ageOnly))
              'age': ?p.age
            else
              'birthDate': ?p.birthDate,
            'answers': {
              for (final q in personQuestions)
                if (shows(q, draft, person: p) && !_empty(p.answers[q.id]))
                  q.id: p.answers[q.id],
            },
            if (has(RegistrationBlock.stay)) ...{
              'arrivalAt': ?p.arrivalAt?.millisecondsSinceEpoch,
              'departureAt': ?p.departureAt?.millisecondsSinceEpoch,
            },
            if (has(RegistrationBlock.sessionChoices) && p.signUps.isNotEmpty)
              'signUps': p.signUps.toList()..sort(),
            if (has(RegistrationBlock.sessionChoices) && p.optOuts.isNotEmpty)
              'optOuts': p.optOuts.toList()..sort(),
            if (_accepting(p) case final ids when ids.isNotEmpty)
              'acceptWaivers': ids,
            'photoConsent': ?p.photoConsent,
          },
      ],
    };
  }

  /// [person]'s accepted waivers that still apply, sorted.
  List<String> _accepting(PersonEntry person) {
    final applies = {for (final w in waiversFor(person)) w.id};
    return person.acceptWaivers.where(applies.contains).toList()..sort();
  }
}
