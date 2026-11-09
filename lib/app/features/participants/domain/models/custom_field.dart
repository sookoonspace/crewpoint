import 'package:flutter/foundation.dart';

/// What a custom field asks for (Req 41).
enum FieldType { text, number, date, singleChoice, multiChoice, yesNo }

/// Whether a field is answered per person or once for their group.
enum FieldScope { participant, group }

/// Who sees an answer. Standard answers are seen wherever the person or
/// group is; private ones only with `participants.readPrivate` or by the
/// group's linked adults, and are stored in `private`.
enum FieldVisibility { standard, private }

/// A question an organizer adds, such as a diet or a meal choice, in
/// `events/{id}/fields/{fieldId}`.
@immutable
class CustomField {
  const CustomField({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
    this.required = false,
    this.scope = FieldScope.participant,
    this.visibility = FieldVisibility.standard,
    this.order = 0,
  });

  factory CustomField.fromFirestore(String id, Map<String, dynamic> data) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return CustomField(
      id: id,
      label: data['label'] as String? ?? '',
      type: pick(FieldType.values, data['type'], FieldType.text),
      options: [
        for (final o in (data['options'] as List?) ?? const [])
          if (o is String) o,
      ],
      required: data['required'] == true,
      scope: pick(FieldScope.values, data['scope'], FieldScope.participant),
      visibility: pick(
        FieldVisibility.values,
        data['visibility'],
        FieldVisibility.standard,
      ),
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String label;
  final FieldType type;
  final List<String> options;
  final bool required;
  final FieldScope scope;
  final FieldVisibility visibility;
  final int order;

  bool get isPrivate => visibility == FieldVisibility.private;

  CustomField copyWith({
    String? label,
    FieldType? type,
    List<String>? options,
    bool? required,
    FieldScope? scope,
    FieldVisibility? visibility,
    int? order,
  }) => CustomField(
    id: id,
    label: label ?? this.label,
    type: type ?? this.type,
    options: options ?? this.options,
    required: required ?? this.required,
    scope: scope ?? this.scope,
    visibility: visibility ?? this.visibility,
    order: order ?? this.order,
  );

  bool get hasOptions =>
      type == FieldType.singleChoice || type == FieldType.multiChoice;

  /// Whether the roster can filter by it: standard choice and yes/no only,
  /// so private answers never reach a query.
  bool get filters => !isPrivate && (hasOptions || type == FieldType.yesNo);

  Map<String, Object> toMap() => {
    'label': label,
    'type': type.name,
    'options': hasOptions ? options : const <String>[],
    'required': required,
    'scope': scope.name,
    'visibility': visibility.name,
    'order': order,
  };

  @override
  bool operator ==(Object other) =>
      other is CustomField &&
      other.id == id &&
      other.label == label &&
      other.type == type &&
      listEquals(other.options, options) &&
      other.required == required &&
      other.scope == scope &&
      other.visibility == visibility &&
      other.order == order;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    type,
    Object.hashAll(options),
    required,
    scope,
    visibility,
    order,
  );
}

/// Why an answer cannot be saved.
enum AnswerProblem { required, wrongType, notAnOption, tooLong }

const maxTextAnswer = 500;

bool _isEmpty(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is List && value.isEmpty);

/// Null when [value] is a fine answer to [field].
AnswerProblem? checkAnswer(CustomField field, Object? value) {
  if (_isEmpty(value)) return field.required ? AnswerProblem.required : null;
  switch (field.type) {
    case FieldType.text:
      if (value is! String) return AnswerProblem.wrongType;
      return value.length > maxTextAnswer ? AnswerProblem.tooLong : null;
    case FieldType.number:
      return value is num ? null : AnswerProblem.wrongType;
    case FieldType.date:
      return value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
          ? null
          : AnswerProblem.wrongType;
    case FieldType.yesNo:
      return value is bool ? null : AnswerProblem.wrongType;
    case FieldType.singleChoice:
      if (value is! String) return AnswerProblem.wrongType;
      return field.options.contains(value) ? null : AnswerProblem.notAnOption;
    case FieldType.multiChoice:
      if (value is! List) return AnswerProblem.wrongType;
      return value.every(field.options.contains)
          ? null
          : AnswerProblem.notAnOption;
  }
}

/// A roster filter: [fieldId] answered [value].
String filterTag(String fieldId, Object value) =>
    '$fieldId=${value is bool ? (value ? 'yes' : 'no') : value}';

/// The tags saved with someone's standard answers, so the roster can filter
/// by them. Private answers are never tagged.
List<String> filterTagsFor(
  List<CustomField> fields,
  Map<String, Object?> answers,
) => [
  for (final f in fields)
    if (f.filters)
      if (answers[f.id] case final value?)
        if (value is List)
          for (final v in value) filterTag(f.id, v as Object)
        else if (!_isEmpty(value))
          filterTag(f.id, value),
];
