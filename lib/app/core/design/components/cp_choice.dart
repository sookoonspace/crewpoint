import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/cp_feedback.dart';
import 'package:crewpoint_app/app/core/design/components/cp_fields.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// One answer a person can pick.
@immutable
class CpChoice<T> {
  const CpChoice(this.value, this.label, {this.key});

  final T value;
  final String label;

  /// For tests, such as `Key('people.answer.diet.veg')`.
  final Key? key;
}

/// Answers as tappable chips (Spec #186 L5): one choice, or several with
/// [multiple]. Choices wrap onto more lines rather than hiding in a menu.
/// Tapping a chosen single choice again clears it unless [required].
class CpChoiceChips<T> extends StatelessWidget {
  const CpChoiceChips({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.multiple = false,
    this.required = false,
    this.requiredLabel,
    this.help,
    this.error,
    this.labelIcon,
  });

  final String label;
  final List<CpChoice<T>> choices;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onChanged;
  final bool multiple;
  final bool required;
  final String? requiredLabel;
  final String? help;
  final String? error;
  final IconData? labelIcon;

  void _tap(BuildContext context, T value) {
    cpSelectionFeedback(context);
    final next = {...selected};
    if (multiple) {
      next.contains(value) ? next.remove(value) : next.add(value);
    } else if (next.contains(value)) {
      if (!required) next.clear();
    } else {
      next
        ..clear()
        ..add(value);
    }
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return CpField(
      label: label,
      required: required,
      requiredLabel: requiredLabel,
      help: help,
      error: error,
      labelIcon: labelIcon,
      child: Wrap(
        spacing: cp.space.sm,
        // Each chip's tap area reaches above and below it, filling the gap.
        runSpacing: 0,
        children: [
          for (final choice in choices)
            _ChoicePill(
              key: choice.key,
              label: choice.label,
              selected: selected.contains(choice.value),
              hasError: error != null,
              exclusive: !multiple,
              onTap: onChanged == null
                  ? null
                  : () => _tap(context, choice.value),
            ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.hasError,
    required this.exclusive,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool hasError;
  final bool exclusive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final c = cp.colors;
    final fg = selected ? c.onAccent : c.text;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: exclusive,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      // A transparent margin above and below the chip also takes the tap,
      // so the target is at least 48 px while the chip looks lighter.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: cp.space.xs),
          child: Material(
            color: selected ? c.accent : c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: cp.radii.pill,
              side: BorderSide(
                color: selected
                    ? c.accent
                    : hasError
                    ? c.overdue
                    : c.border,
                width: cp.sizes.hairline,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: RoundedRectangleBorder(borderRadius: cp.radii.pill),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: cp.sizes.tapMin - cp.space.sm,
                  minWidth: cp.sizes.tapMin,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: cp.space.md + 2,
                    vertical: cp.space.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: cp.space.xs + 2,
                    children: [
                      if (selected)
                        Icon(CpIcons.check, size: cp.sizes.iconSm, color: fg),
                      Flexible(
                        child: Text(
                          label,
                          style: cp.type.titleSmall.copyWith(
                            color: fg,
                            fontSize: cp.type.labelLarge.fontSize! - 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two to four exclusive options side by side, such as Adult or Child, or
/// Yes or No. Use [CpChoiceChips] when there are more or labels are long.
class CpSegmented<T> extends StatelessWidget {
  const CpSegmented({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
  }) : assert(choices.length >= 2 && choices.length <= 4);

  final List<CpChoice<T>> choices;
  final T? selected;
  final ValueChanged<T>? onChanged;

  /// What is being chosen, such as "Kids activities".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final c = cp.colors;
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: EdgeInsets.all(cp.space.xs - 1),
        decoration: BoxDecoration(
          color: c.fill,
          borderRadius: cp.radii.sm,
          border: Border.all(color: c.border, width: cp.sizes.hairline),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.xs - 2,
            children: [
              for (final choice in choices)
                Expanded(
                  child: _Segment(
                    key: choice.key,
                    label: choice.label,
                    selected: choice.value == selected,
                    onTap: onChanged == null
                        ? null
                        : () {
                            if (choice.value == selected) return;
                            cpSelectionFeedback(context);
                            onChanged!(choice.value);
                          },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final c = cp.colors;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? c.surface : Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: cp.radii.sm - BorderRadius.circular(cp.space.xs / 2),
          side: selected
              ? BorderSide(color: c.border, width: cp.sizes.hairline)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: cp.radii.sm,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: cp.sizes.tapMin - cp.space.sm,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: cp.space.sm),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: cp.type.labelLarge.copyWith(
                    color: selected ? c.text : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
