import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';

/// One custom field's answer, in the form its type needs (Req 41). Checked
/// with [checkAnswer] when the form is saved. Keyed `people.answer.<id>`.
class FieldAnswerInput extends StatelessWidget {
  const FieldAnswerInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final CustomField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final bool enabled;

  String? _message(BuildContext context, Object? v) {
    final strings = context.strings.fields;
    return switch (checkAnswer(field, v)) {
      null => null,
      AnswerProblem.required => strings.answerRequired,
      AnswerProblem.tooLong => strings.answerTooLong,
      AnswerProblem.wrongType ||
      AnswerProblem.notAnOption => strings.answerWrong,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.fields;
    final key = Key('people.answer.${field.id}');
    final label = [
      field.label,
      if (field.required) '*',
      if (field.isPrivate) '(${strings.privateBadge})',
    ].join(' ');
    final decoration = InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );

    switch (field.type) {
      case FieldType.text:
      case FieldType.number:
        final isNumber = field.type == FieldType.number;
        return TextFormField(
          key: key,
          initialValue: value?.toString() ?? '',
          enabled: enabled,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: decoration,
          onChanged: (text) {
            final trimmed = text.trim();
            onChanged(
              trimmed.isEmpty
                  ? null
                  : isNumber
                  ? (num.tryParse(trimmed) ?? trimmed)
                  : text,
            );
          },
          validator: (_) => _message(context, value),
        );
      case FieldType.date:
        return FormField<Object?>(
          key: key,
          initialValue: value,
          validator: (_) => _message(context, value),
          builder: (state) => InputDecorator(
            decoration: decoration.copyWith(errorText: state.errorText),
            child: InkWell(
              onTap: enabled
                  ? () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(value as String? ?? '') ?? now,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (picked == null) return;
                      onChanged(
                        '${picked.year.toString().padLeft(4, '0')}-'
                        '${picked.month.toString().padLeft(2, '0')}-'
                        '${picked.day.toString().padLeft(2, '0')}',
                      );
                    }
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(value as String? ?? strings.chooseDate),
                    ),
                    const Icon(AppIcons.calendar),
                  ],
                ),
              ),
            ),
          ),
        );
      case FieldType.yesNo:
        return DropdownButtonFormField<bool>(
          key: key,
          isExpanded: true,
          initialValue: value is bool ? value as bool : null,
          decoration: decoration,
          items: [
            DropdownMenuItem(value: true, child: Text(strings.yes)),
            DropdownMenuItem(value: false, child: Text(strings.no)),
          ],
          onChanged: enabled ? onChanged : null,
          validator: (_) => _message(context, value),
        );
      case FieldType.singleChoice:
        return DropdownButtonFormField<String>(
          key: key,
          isExpanded: true,
          initialValue: field.options.contains(value) ? value as String : null,
          decoration: decoration,
          items: [
            for (final o in field.options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: enabled ? onChanged : null,
          validator: (_) => _message(context, value),
        );
      case FieldType.multiChoice:
        final chosen = value is List ? value as List : const <Object?>[];
        return FormField<Object?>(
          key: key,
          initialValue: value,
          validator: (_) => _message(context, value),
          builder: (state) => InputDecorator(
            decoration: decoration.copyWith(errorText: state.errorText),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final o in field.options)
                  FilterChip(
                    key: Key('people.answer.${field.id}.$o'),
                    label: Text(o),
                    selected: chosen.contains(o),
                    onSelected: enabled
                        ? (on) {
                            final next = [
                              for (final x in field.options)
                                if (x == o ? on : chosen.contains(x)) x,
                            ];
                            onChanged(next.isEmpty ? null : next);
                          }
                        : null,
                  ),
              ],
            ),
          ),
        );
    }
  }
}
