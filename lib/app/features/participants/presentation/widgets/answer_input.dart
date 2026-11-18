import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';

/// One custom question in the design system's look (Spec #186 Req 29):
/// choices as tappable chips, yes or no side by side, dates in the
/// platform's picker. Text answers own their controller here, so it lives
/// exactly as long as the question is on screen.
///
/// Keys: `{keyPrefix}.answer.{fieldId}` on the input, and
/// `{keyPrefix}.answer.{fieldId}.{option}` on each choice.
class AnswerInput extends StatefulWidget {
  const AnswerInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
    this.showError = false,
  });

  final CustomField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String keyPrefix;

  /// Shows what is wrong with [value], once a save has been tried.
  final bool showError;

  @override
  State<AnswerInput> createState() => _AnswerInputState();
}

class _AnswerInputState extends State<AnswerInput> {
  TextEditingController? _text;

  bool get _typed =>
      widget.field.type == FieldType.text ||
      widget.field.type == FieldType.number;

  @override
  void initState() {
    super.initState();
    if (_typed) {
      _text = TextEditingController(text: widget.value?.toString() ?? '');
    }
  }

  @override
  void didUpdateWidget(AnswerInput old) {
    super.didUpdateWidget(old);
    // Answers copied from someone else ("Same answers as") arrive here.
    final text = _text;
    if (text != null && widget.value != _parse(text.text)) {
      text.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _text?.dispose();
    super.dispose();
  }

  Object? _parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (widget.field.type == FieldType.number) {
      return num.tryParse(trimmed) ?? trimmed;
    }
    return raw;
  }

  String? _error(BuildContext context) {
    if (!widget.showError) return null;
    final strings = context.strings.groupEntry;
    final fields = context.strings.fields;
    final typed = _typed;
    return switch (checkAnswer(widget.field, widget.value)) {
      null => null,
      AnswerProblem.required =>
        typed ? strings.enterAnswer : strings.chooseAnswer,
      AnswerProblem.tooLong => fields.answerTooLong,
      AnswerProblem.wrongType ||
      AnswerProblem.notAnOption => fields.answerWrong,
    };
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final strings = context.strings.groupEntry;
    final key = '${widget.keyPrefix}.answer.${field.id}';
    final error = _error(context);
    final labelIcon = field.isPrivate ? CpIcons.lock : null;
    final value = widget.value;
    switch (field.type) {
      case FieldType.text:
      case FieldType.number:
        return CpTextField(
          label: field.label,
          fieldKey: Key(key),
          controller: _text,
          required: field.required,
          requiredLabel: strings.required,
          labelIcon: labelIcon,
          error: error,
          keyboardType: field.type == FieldType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          maxLength: field.type == FieldType.text ? maxTextAnswer : null,
          onChanged: (raw) => widget.onChanged(_parse(raw)),
        );
      case FieldType.date:
        final now = DateTime.now();
        final date = value is String ? DateTime.tryParse(value) : null;
        return CpDateField(
          key: Key(key),
          label: field.label,
          value: date,
          required: field.required,
          requiredLabel: strings.required,
          labelIcon: labelIcon,
          error: error,
          firstDate: DateTime(1900),
          lastDate: DateTime(now.year + 10),
          format: (d) => MaterialLocalizations.of(context).formatMediumDate(d),
          clearLabel: field.required
              ? null
              : MaterialLocalizations.of(context).deleteButtonTooltip,
          onChanged: (d) => widget.onChanged(d == null ? null : _isoDate(d)),
        );
      case FieldType.yesNo:
        return CpField(
          label: field.label,
          required: field.required,
          requiredLabel: strings.required,
          labelIcon: labelIcon,
          error: error,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.cp.sizes.avatarLg * 4,
              ),
              child: CpSegmented<bool>(
                key: Key(key),
                semanticLabel: field.label,
                choices: [
                  CpChoice(true, strings.yes, key: Key('$key.yes')),
                  CpChoice(false, strings.no, key: Key('$key.no')),
                ],
                selected: value is bool ? value : null,
                onChanged: widget.onChanged,
              ),
            ),
          ),
        );
      case FieldType.singleChoice:
      case FieldType.multiChoice:
        final multiple = field.type == FieldType.multiChoice;
        final chosen = <String>{
          if (value is String) value,
          if (value is List) ...value.whereType<String>(),
        };
        return CpChoiceChips<String>(
          key: Key(key),
          label: field.label,
          multiple: multiple,
          required: field.required,
          requiredLabel: strings.required,
          labelIcon: labelIcon,
          error: error,
          choices: [
            for (final o in field.options) CpChoice(o, o, key: Key('$key.$o')),
          ],
          selected: chosen,
          onChanged: (next) => widget.onChanged(
            next.isEmpty
                ? null
                : multiple
                // Keep the organizer's order.
                ? [
                    for (final o in field.options)
                      if (next.contains(o)) o,
                  ]
                : next.single,
          ),
        );
    }
  }
}

/// A calendar date as `YYYY-MM-DD`.
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
