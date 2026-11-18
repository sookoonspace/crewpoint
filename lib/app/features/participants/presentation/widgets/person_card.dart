import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/group_draft.dart';
import 'package:crewpoint_app/app/features/participants/presentation/widgets/answer_input.dart';

/// One person on the group screen (Spec #186 Req 28): name, adult or child,
/// a child's birth date or an adult's email, and their answers inline.
///
/// A plain widget over a [PersonDraft], so Stage 2's registration form can
/// reuse it (Req 38). It owns its text controllers, which live as long as
/// the card. Keys start `{keyPrefix}`, such as
/// `people.groupEntry.person.0.name`.
class PersonCard extends StatefulWidget {
  const PersonCard({
    super.key,
    required this.number,
    required this.person,
    required this.fields,
    required this.onChanged,
    required this.keyPrefix,
    required this.categories,
    required this.eventStart,
    this.onRemove,
    this.onCopyPrevious,
    this.previousName,
    this.check,
  });

  /// Shown as "Person {number}".
  final int number;
  final PersonDraft person;

  /// The participant questions this viewer may see and answer.
  final List<CustomField> fields;
  final ValueChanged<PersonDraft> onChanged;
  final String keyPrefix;

  /// For the age band a child's birth date sets.
  final List<EventCategory> categories;
  final DateTime eventStart;
  final VoidCallback? onRemove;

  /// "Same answers as" the person before; null on the first card.
  final VoidCallback? onCopyPrevious;
  final String? previousName;

  /// What is missing, once a save has been tried.
  final PersonCheck? check;

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.person.name,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.person.email,
  );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  PersonDraft get _person => widget.person;

  void _change(PersonDraft next) => widget.onChanged(next);

  void _answer(CustomField field, Object? value) {
    final target = field.isPrivate
        ? {..._person.privateAnswers, field.id: value}
        : {..._person.answers, field.id: value};
    target.removeWhere((_, v) => v == null);
    _change(
      field.isPrivate
          ? _person.copyWith(privateAnswers: target)
          : _person.copyWith(answers: target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.groupEntry;
    final prefix = widget.keyPrefix;
    final check = widget.check;
    final band = categoryFor(
      _person.birthDate,
      widget.eventStart,
      widget.categories,
    )?.name;
    final now = DateTime.now();
    final previous = widget.previousName?.trim() ?? '';

    return CpCard(
      key: Key(prefix),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.personTitle(widget.number),
                    style: cp.type.titleSmall.copyWith(
                      color: cp.colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  key: Key('$prefix.remove'),
                  tooltip: strings.removePerson,
                  onPressed: widget.onRemove,
                  icon: Icon(
                    CpIcons.actionDelete,
                    size: cp.sizes.iconMd,
                    color: cp.colors.textMuted,
                  ),
                ),
            ],
          ),
          if (widget.onCopyPrevious != null)
            Align(
              alignment: Alignment.centerLeft,
              child: CpButton.secondary(
                key: Key('$prefix.copy'),
                icon: CpIcons.actionCopy,
                label: previous.isEmpty
                    ? strings.sameAnswersAsPrevious
                    : strings.sameAnswersAs(previous),
                onPressed: widget.onCopyPrevious,
              ),
            ),
          CpTextField(
            label: strings.nameLabel,
            fieldKey: Key('$prefix.name'),
            controller: _name,
            required: true,
            requiredLabel: strings.required,
            error: check?.nameMissing == true ? strings.nameRequired : null,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            onChanged: (v) => _change(_person.copyWith(name: v)),
          ),
          CpSegmented<bool>(
            key: Key('$prefix.age'),
            semanticLabel: '${strings.adult} / ${strings.child}',
            choices: [
              CpChoice(false, strings.adult, key: Key('$prefix.adult')),
              CpChoice(true, strings.child, key: Key('$prefix.child')),
            ],
            selected: _person.isChild,
            onChanged: (child) => _change(_person.copyWith(isChild: child)),
          ),
          if (_person.isChild)
            CpDateField(
              key: Key('$prefix.birthDate'),
              label: strings.birthDateLabel,
              labelIcon: CpIcons.lock,
              value: DateTime.tryParse(_person.birthDate ?? ''),
              placeholder: '',
              help: strings.birthDateHelp(band),
              firstDate: DateTime(1900),
              lastDate: now,
              clearLabel: strings.clearBirthDate,
              format: (d) =>
                  MaterialLocalizations.of(context).formatMediumDate(d),
              onChanged: (d) => _change(
                d == null
                    ? _person.copyWith(clearBirthDate: true)
                    : _person.copyWith(birthDate: _isoDate(d)),
              ),
            )
          else
            CpTextField(
              label: strings.emailLabel,
              labelIcon: CpIcons.lock,
              fieldKey: Key('$prefix.email'),
              controller: _email,
              help: strings.emailHelp,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (v) => _change(_person.copyWith(email: v.trim())),
            ),
          for (final field in widget.fields)
            AnswerInput(
              key: Key('$prefix.question.${field.id}'),
              field: field,
              keyPrefix: prefix,
              value: field.isPrivate
                  ? _person.privateAnswers[field.id]
                  : _person.answers[field.id],
              showError: check?.missing.contains(field.id) ?? false,
              onChanged: (v) => _answer(field, v),
            ),
        ],
      ),
    );
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
