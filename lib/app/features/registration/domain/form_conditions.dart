import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// Whether a form question is shown to a person (Spec #233 Req 18; #242):
/// to one category, or when one other answer has a value. Hidden questions
/// are never required and their answers are not saved. The server's
/// `functions/src/registration/conditions.ts` runs the same cases
/// (`functions/test/fixtures/condition_cases.json`); change them together.
///
/// [categoryId] is null while the person's category is unknown; [answers]
/// holds the person's answers and their group's, by question ID.
bool isShown(
  FieldCondition? condition, {
  required String? categoryId,
  required Map<String, Object?> answers,
}) => switch (condition) {
  null => true,
  CategoryCondition(categoryId: final wanted) => categoryId == wanted,
  AnswerCondition(:final fieldId, :final value) => switch (answers[fieldId]) {
    null => false,
    final List<Object?> chosen => chosen.any((a) => _asText(a) == value),
    final answer => _asText(answer) == value,
  },
};

/// An answer as conditions compare it: yes/no as `yes` or `no`.
String _asText(Object? value) =>
    value is bool ? (value ? 'yes' : 'no') : '$value';
