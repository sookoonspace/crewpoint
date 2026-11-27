import 'package:flutter/foundation.dart';

/// Who may register (Spec #233 Req 8): anyone with the event's link, or
/// only groups the organizer invited.
enum RegistrationMode { open, invited }

/// Text an organizer writes, in English and, when given, Gujarati (Req 58).
@immutable
class LocalText {
  const LocalText(this.en, {this.gu});

  static LocalText? tryParse(Object? raw) {
    if (raw is! Map || raw['en'] is! String) return null;
    final en = (raw['en'] as String).trim();
    if (en.isEmpty) return null;
    final gu = raw['gu'];
    return LocalText(en, gu: gu is String && gu.trim().isNotEmpty ? gu : null);
  }

  final String en;
  final String? gu;

  Map<String, String> toMap() => {'en': en, 'gu': ?gu};

  @override
  bool operator ==(Object other) =>
      other is LocalText && other.en == en && other.gu == gu;

  @override
  int get hashCode => Object.hash(en, gu);
}

/// A named, ordered part of the form, listing the event's questions (Req
/// 16).
@immutable
class RegistrationSection {
  const RegistrationSection({
    required this.id,
    required this.name,
    this.fieldIds = const [],
  });

  static RegistrationSection? tryParse(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    return RegistrationSection(
      id: raw['id'] as String,
      name: LocalText.tryParse(raw['name']) ?? const LocalText(''),
      fieldIds: [
        for (final id in (raw['fieldIds'] as List?) ?? const [])
          if (id is String) id,
      ],
    );
  }

  final String id;
  final LocalText name;
  final List<String> fieldIds;

  RegistrationSection copyWith({LocalText? name, List<String>? fieldIds}) =>
      RegistrationSection(
        id: id,
        name: name ?? this.name,
        fieldIds: fieldIds ?? this.fieldIds,
      );

  Map<String, Object> toMap() => {
    'id': id,
    'name': name.toMap(),
    'fieldIds': fieldIds,
  };

  @override
  bool operator ==(Object other) =>
      other is RegistrationSection &&
      other.id == id &&
      other.name == name &&
      listEquals(other.fieldIds, fieldIds);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(fieldIds));
}

/// The built-in parts of the form (Req 17).
enum RegistrationBlock {
  people,
  ageOnly,
  stay,
  sessionChoices,
  waivers,
  contact,
}

/// Shown only to a category, or when one other answer has a value (Req 18).
@immutable
sealed class FieldCondition {
  const FieldCondition();

  static FieldCondition? tryParse(Object? raw) {
    if (raw is! Map) return null;
    if (raw['categoryId'] is String) {
      return CategoryCondition(raw['categoryId'] as String);
    }
    if (raw['fieldId'] is String && raw['value'] is String) {
      return AnswerCondition(raw['fieldId'] as String, raw['value'] as String);
    }
    return null;
  }

  Map<String, String> toMap();
}

class CategoryCondition extends FieldCondition {
  const CategoryCondition(this.categoryId);

  final String categoryId;

  @override
  Map<String, String> toMap() => {'categoryId': categoryId};

  @override
  bool operator ==(Object other) =>
      other is CategoryCondition && other.categoryId == categoryId;

  @override
  int get hashCode => categoryId.hashCode;
}

class AnswerCondition extends FieldCondition {
  const AnswerCondition(this.fieldId, this.value);

  final String fieldId;

  /// `yes` or `no` for a yes/no question, else one of its options.
  final String value;

  @override
  Map<String, String> toMap() => {'fieldId': fieldId, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is AnswerCondition &&
      other.fieldId == fieldId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(fieldId, value);
}

/// An event's registration settings, `settings.registration` (#239),
/// written only by `saveRegistrationSettings` and, for [slug],
/// `claimEventSlug`. The server checks everything again; this side keeps
/// the screen from offering what it would refuse.
@immutable
class RegistrationSettings {
  const RegistrationSettings({
    this.mode = RegistrationMode.invited,
    this.deadline,
    this.review = false,
    this.extraGuests = 0,
    this.sections = const [],
    this.blocks = defaultBlocks,
    this.conditions = const {},
    this.included,
    this.contactLine,
    this.afterNote,
    this.laterNote,
    this.laterNoteFrom,
    this.registrationRoleId = 'participant',
    this.offerHours = 72,
    this.slug,
  });

  static const defaultBlocks = {
    RegistrationBlock.people,
    RegistrationBlock.contact,
  };

  /// The event's stored settings, with anything missing taken from its
  /// template's ([template]) and then the platform's, as the server reads
  /// them.
  factory RegistrationSettings.fromMaps(Object? stored, Object? template) {
    Map<Object?, Object?> map(Object? raw) => raw is Map ? raw : const {};
    final s = map(stored);
    final t = map(template);
    Object? pick(String key) => s.containsKey(key) ? s[key] : t[key];
    DateTime? time(Object? raw) => raw is num
        ? DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true)
        : null;
    final storedBlocks = map(s['blocks']);
    final templateBlocks = map(t['blocks']);
    final blocks = {
      for (final b in RegistrationBlock.values)
        if ((storedBlocks[b.name] ??
                templateBlocks[b.name] ??
                defaultBlocks.contains(b)) ==
            true)
          b,
    };
    final rawConditions = map(pick('conditions'));
    return RegistrationSettings(
      mode: pick('mode') == 'open'
          ? RegistrationMode.open
          : RegistrationMode.invited,
      deadline: time(pick('deadline')),
      review: pick('review') == true,
      extraGuests: (pick('extraGuests') as num?)?.toInt() ?? 0,
      sections: [
        for (final raw in (pick('sections') as List?) ?? const [])
          ?RegistrationSection.tryParse(raw),
      ],
      blocks: blocks,
      conditions: {
        for (final e in rawConditions.entries)
          if (e.key is String && FieldCondition.tryParse(e.value) != null)
            e.key as String: FieldCondition.tryParse(e.value)!,
      },
      included: LocalText.tryParse(pick('included')),
      contactLine: LocalText.tryParse(pick('contactLine')),
      afterNote: LocalText.tryParse(pick('afterNote')),
      laterNote: LocalText.tryParse(pick('laterNote')),
      laterNoteFrom: time(pick('laterNoteFrom')),
      registrationRoleId:
          pick('registrationRoleId') as String? ?? 'participant',
      offerHours: (pick('offerHours') as num?)?.toInt() ?? 72,
      slug: s['slug'] as String?,
    );
  }

  final RegistrationMode mode;

  /// When registration closes, an instant shown in the event's time zone.
  final DateTime? deadline;
  final bool review;
  final int extraGuests;
  final List<RegistrationSection> sections;
  final Set<RegistrationBlock> blocks;

  /// By question ID.
  final Map<String, FieldCondition> conditions;

  /// What the event includes, on its public page (Req 10).
  final LocalText? included;

  /// How to reach the organizer, shown once registration closes (#244).
  final LocalText? contactLine;
  final LocalText? afterNote;
  final LocalText? laterNote;
  final DateTime? laterNoteFrom;
  final String registrationRoleId;
  final int offerHours;

  /// The name in the event's public link, `/e/:slug`, once claimed.
  final String? slug;

  bool has(RegistrationBlock block) => blocks.contains(block);

  /// The questions other questions depend on. They are always shown, so
  /// they cannot have a condition themselves (Req 18).
  Set<String> get dependedOn => {
    for (final c in conditions.values)
      if (c is AnswerCondition) c.fieldId,
  };

  /// Whether [fieldId] may depend on [targetId]: another question that has
  /// no condition, while nothing depends on [fieldId].
  bool canDependOn(String fieldId, String targetId) =>
      fieldId != targetId &&
      !conditions.containsKey(targetId) &&
      !dependedOn.contains(fieldId);

  /// The section [fieldId] is in, if any.
  RegistrationSection? sectionOf(String fieldId) =>
      sections.where((s) => s.fieldIds.contains(fieldId)).firstOrNull;

  RegistrationSettings copyWith({
    RegistrationMode? mode,
    DateTime? deadline,
    bool clearDeadline = false,
    bool? review,
    int? extraGuests,
    List<RegistrationSection>? sections,
    Set<RegistrationBlock>? blocks,
    Map<String, FieldCondition>? conditions,
    LocalText? included,
    bool clearIncluded = false,
    LocalText? contactLine,
    bool clearContactLine = false,
    LocalText? afterNote,
    bool clearAfterNote = false,
    LocalText? laterNote,
    bool clearLaterNote = false,
    DateTime? laterNoteFrom,
    bool clearLaterNoteFrom = false,
    String? registrationRoleId,
    int? offerHours,
    String? slug,
  }) => RegistrationSettings(
    mode: mode ?? this.mode,
    deadline: clearDeadline ? null : deadline ?? this.deadline,
    review: review ?? this.review,
    extraGuests: extraGuests ?? this.extraGuests,
    sections: sections ?? this.sections,
    blocks: blocks ?? this.blocks,
    conditions: conditions ?? this.conditions,
    included: clearIncluded ? null : included ?? this.included,
    contactLine: clearContactLine ? null : contactLine ?? this.contactLine,
    afterNote: clearAfterNote ? null : afterNote ?? this.afterNote,
    laterNote: clearLaterNote ? null : laterNote ?? this.laterNote,
    laterNoteFrom: clearLaterNoteFrom
        ? null
        : laterNoteFrom ?? this.laterNoteFrom,
    registrationRoleId: registrationRoleId ?? this.registrationRoleId,
    offerHours: offerHours ?? this.offerHours,
    slug: slug ?? this.slug,
  );

  /// Sets [fieldId]'s condition, or clears it with null.
  RegistrationSettings withCondition(String fieldId, FieldCondition? c) =>
      copyWith(
        conditions: {
          for (final e in conditions.entries)
            if (e.key != fieldId) e.key: e.value,
          fieldId: ?c,
        },
      );

  /// What `saveRegistrationSettings` takes. The slug is left out: only
  /// `claimEventSlug` changes it.
  Map<String, Object?> toCallMap() => {
    'mode': mode.name,
    'deadline': deadline?.millisecondsSinceEpoch,
    'review': review,
    'extraGuests': extraGuests,
    'sections': [for (final s in sections) s.toMap()],
    'blocks': {
      for (final b in RegistrationBlock.values) b.name: blocks.contains(b),
    },
    'conditions': {for (final e in conditions.entries) e.key: e.value.toMap()},
    'included': included?.toMap(),
    'contactLine': contactLine?.toMap(),
    'afterNote': afterNote?.toMap(),
    'laterNote': laterNote?.toMap(),
    'laterNoteFrom': laterNote == null
        ? null
        : laterNoteFrom?.millisecondsSinceEpoch,
    'registrationRoleId': registrationRoleId,
    'offerHours': offerHours,
  };

  @override
  bool operator ==(Object other) =>
      other is RegistrationSettings &&
      other.mode == mode &&
      other.deadline == deadline &&
      other.review == review &&
      other.extraGuests == extraGuests &&
      listEquals(other.sections, sections) &&
      setEquals(other.blocks, blocks) &&
      mapEquals(other.conditions, conditions) &&
      other.included == included &&
      other.contactLine == contactLine &&
      other.afterNote == afterNote &&
      other.laterNote == laterNote &&
      other.laterNoteFrom == laterNoteFrom &&
      other.registrationRoleId == registrationRoleId &&
      other.offerHours == offerHours &&
      other.slug == slug;

  @override
  int get hashCode => Object.hash(
    mode,
    deadline,
    review,
    extraGuests,
    Object.hashAll(sections),
    Object.hashAll(blocks.map((b) => b.index).toList()..sort()),
    Object.hashAll(conditions.keys.toList()..sort()),
    included,
    contactLine,
    afterNote,
    laterNote,
    laterNoteFrom,
    registrationRoleId,
    offerHours,
    slug,
  );
}

/// The only permissions the role for people who register may hold, as the
/// server allows: anyone may register on an open event.
const selfServicePermissions = {
  'chat.send',
  'chat.urgent',
  'group.readOwn',
  'group.editOwn',
  'incidents.report',
  'scores.enter',
};

/// Whether a role with [permissions] can be given to people who register.
bool canBeRegistrationRole(String roleId, Iterable<String> permissions) =>
    roleId != 'owner' && permissions.every(selfServicePermissions.contains);

/// Lower-case letters, numbers and hyphens, 3 to 40 long, starting and
/// ending with a letter or number: the form the server keeps. Reserved
/// words are refused by the server.
String? normaliseSlug(String raw) {
  final slug = raw.trim().toLowerCase();
  return RegExp(r'^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$').hasMatch(slug)
      ? slug
      : null;
}
