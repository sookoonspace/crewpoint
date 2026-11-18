import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:crewpoint_app/app/core/design/components/cp_feedback.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// The parts every field shares: a label above (with a red star when
/// required), the input, then help text, or the error in its place.
///
/// Use it to give a custom input the same frame as the built-in fields.
class CpField extends StatelessWidget {
  const CpField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.requiredLabel,
    this.help,
    this.error,
    this.labelIcon,
  });

  final String label;
  final Widget child;
  final bool required;

  /// Read after the label when [required], such as "required". Screen
  /// readers skip the star itself.
  final String? requiredLabel;
  final String? help;

  /// Shown instead of [help], in red with an icon.
  final String? error;

  /// A small icon before the label, such as a lock for private fields.
  final IconData? labelIcon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.xs + 2,
      children: [
        CpFieldLabel(
          label: label,
          required: required,
          requiredLabel: requiredLabel,
          icon: labelIcon,
        ),
        child,
        if (error != null)
          CpFieldError(error!)
        else if (help != null)
          Text(
            help!,
            style: cp.type.labelSmall.copyWith(
              color: cp.colors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

/// A field's label, with a red star when required.
class CpFieldLabel extends StatelessWidget {
  const CpFieldLabel({
    super.key,
    required this.label,
    this.required = false,
    this.requiredLabel,
    this.icon,
  });

  final String label;
  final bool required;
  final String? requiredLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Semantics(
      label: required && requiredLabel != null
          ? '$label, $requiredLabel'
          : label,
      excludeSemantics: true,
      child: Row(
        spacing: cp.space.xs + 2,
        children: [
          if (icon != null)
            Icon(icon, size: cp.sizes.iconXs, color: cp.colors.textMuted),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: cp.colors.overdue),
                    ),
                ],
              ),
              style: cp.type.labelMedium.copyWith(color: cp.colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// An error under a field: red, with an icon, announced when it appears.
class CpFieldError extends StatelessWidget {
  const CpFieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.xs,
        children: [
          Padding(
            padding: EdgeInsets.only(top: cp.space.xs / 4),
            child: Icon(
              CpIcons.statusError,
              size: cp.sizes.iconXs,
              color: cp.colors.overdue,
            ),
          ),
          Flexible(
            child: Text(
              message,
              style: cp.type.labelSmall.copyWith(
                color: cp.colors.overdue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoration(
  BuildContext context, {
  String? hint,
  bool hasError = false,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final cp = context.cp;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: cp.radii.sm,
    borderSide: BorderSide(color: color, width: width),
  );
  final idle = hasError
      ? border(cp.colors.overdue, cp.sizes.avatarRing)
      : border(cp.colors.border, cp.sizes.hairline);
  return InputDecoration(
    hintText: hint,
    hintStyle: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
    filled: true,
    fillColor: cp.colors.surface,
    isDense: true,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
    contentPadding: EdgeInsets.symmetric(
      horizontal: cp.space.md,
      vertical: cp.space.md + 1,
    ),
    border: idle,
    enabledBorder: idle,
    disabledBorder: border(cp.colors.border, cp.sizes.hairline),
    focusedBorder: border(
      hasError ? cp.colors.overdue : cp.colors.accent,
      cp.sizes.avatarRing,
    ),
    errorBorder: border(cp.colors.overdue, cp.sizes.avatarRing),
    focusedErrorBorder: border(cp.colors.overdue, cp.sizes.avatarRing),
  );
}

/// A text input with the shared field frame. Works alone (pass [error]) or
/// inside a `Form` (pass [validator]); either way the error shows where the
/// help was, lined up with every other field.
///
/// The caller owns [controller] and disposes it when its own State goes,
/// never when a dialog or sheet returns (#185).
class CpTextField extends StatelessWidget {
  const CpTextField({
    super.key,
    required this.label,
    this.controller,
    this.fieldKey,
    this.required = false,
    this.requiredLabel,
    this.help,
    this.error,
    this.hint,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.prefixIcon,
    this.labelIcon,
    this.autofillHints,
  });

  final String label;
  final TextEditingController? controller;

  /// The key on the input itself, for tests (`domain.feature.field`).
  final Key? fieldKey;
  final bool required;
  final String? requiredLabel;
  final String? help;
  final String? error;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? maxLength;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final IconData? prefixIcon;
  final IconData? labelIcon;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.xs + 2,
      children: [
        CpFieldLabel(
          label: label,
          required: required,
          requiredLabel: requiredLabel,
          icon: labelIcon,
        ),
        FormField<String>(
          initialValue: controller?.text ?? '',
          forceErrorText: error,
          enabled: enabled,
          // Validate what the field holds now, even when the caller set the
          // controller's text directly.
          validator: validator == null
              ? null
              : (value) => validator!(controller?.text ?? value),
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.xs + 2,
            children: [
              TextField(
                key: fieldKey,
                controller: controller,
                onChanged: (value) {
                  state.didChange(value);
                  onChanged?.call(value);
                },
                onSubmitted: onSubmitted,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                inputFormatters: inputFormatters,
                maxLines: maxLines,
                maxLength: maxLength,
                obscureText: obscureText,
                autofocus: autofocus,
                enabled: enabled,
                autofillHints: autofillHints,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                cursorColor: cp.colors.accent,
                decoration: _decoration(
                  context,
                  hint: hint,
                  hasError: state.hasError,
                  prefixIcon: prefixIcon == null
                      ? null
                      : Icon(
                          prefixIcon,
                          size: cp.sizes.iconMd,
                          color: cp.colors.textMuted,
                        ),
                ).copyWith(counterText: maxLength == null ? null : ''),
              ),
              if (state.hasError)
                CpFieldError(state.errorText!)
              else if (help != null)
                Text(
                  help!,
                  style: cp.type.labelSmall.copyWith(
                    color: cp.colors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A field that shows a chosen value and opens a picker when tapped, such
/// as the group picker. The caller opens its own sheet in [onTap].
class CpSelectField extends StatelessWidget {
  const CpSelectField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.required = false,
    this.requiredLabel,
    this.help,
    this.error,
    this.labelIcon,
    this.leadingIcon,
  });

  final String label;

  /// The chosen value's text, or null when nothing is chosen.
  final String? value;

  /// Shown when [value] is null, such as "Choose a group".
  final String? placeholder;
  final VoidCallback? onTap;
  final bool required;
  final String? requiredLabel;
  final String? help;
  final String? error;
  final IconData? labelIcon;
  final IconData? leadingIcon;

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
      child: _TapField(
        semanticLabel: '$label, ${value ?? placeholder ?? ''}',
        onTap: onTap,
        hasError: error != null,
        leading: leadingIcon,
        text: value ?? placeholder ?? '',
        muted: value == null,
        trailing: Icon(
          CpIcons.chevronDown,
          size: cp.sizes.iconMd,
          color: cp.colors.textMuted,
        ),
      ),
    );
  }
}

/// A date field that opens the platform's own picker: a wheel on iOS, the
/// calendar dialog elsewhere (Spec #186 Req 21). Dates show through
/// [format], so the caller decides the wording.
class CpDateField extends StatelessWidget {
  const CpDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.format,
    required this.firstDate,
    required this.lastDate,
    this.placeholder,
    this.clearLabel,
    this.doneLabel,
    this.required = false,
    this.requiredLabel,
    this.help,
    this.error,
    this.labelIcon,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String Function(DateTime) format;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? placeholder;

  /// With a label, a chosen date can be cleared.
  final String? clearLabel;

  /// The iOS wheel's confirm button. Defaults to the platform's OK label.
  final String? doneLabel;
  final bool required;
  final String? requiredLabel;
  final String? help;
  final String? error;
  final IconData? labelIcon;

  Future<void> _pick(BuildContext context) async {
    final initial = value ?? DateTime.now();
    final start = initial.isBefore(firstDate)
        ? firstDate
        : initial.isAfter(lastDate)
        ? lastDate
        : initial;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      final picked = await showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (_) => _CupertinoDateSheet(
          initial: start,
          firstDate: firstDate,
          lastDate: lastDate,
          doneLabel: doneLabel,
        ),
      );
      if (picked != null) onChanged(picked);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final shown = value == null ? placeholder ?? '' : format(value!);
    return CpField(
      label: label,
      required: required,
      requiredLabel: requiredLabel,
      help: help,
      error: error,
      labelIcon: labelIcon,
      child: _TapField(
        semanticLabel: '$label, $shown',
        onTap: () => _pick(context),
        hasError: error != null,
        leading: CpIcons.calendar,
        text: shown,
        muted: value == null,
        trailing: value != null && clearLabel != null
            ? IconButton(
                tooltip: clearLabel,
                onPressed: () => onChanged(null),
                icon: Icon(
                  CpIcons.actionClear,
                  size: cp.sizes.iconMd,
                  color: cp.colors.textMuted,
                ),
              )
            : null,
      ),
    );
  }
}

class _CupertinoDateSheet extends StatefulWidget {
  const _CupertinoDateSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    this.doneLabel,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? doneLabel;

  @override
  State<_CupertinoDateSheet> createState() => _CupertinoDateSheetState();
}

class _CupertinoDateSheetState extends State<_CupertinoDateSheet> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Container(
      color: cp.colors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.of(context).pop(_value),
                child: Text(
                  widget.doneLabel ??
                      MaterialLocalizations.of(context).okButtonLabel,
                ),
              ),
            ),
            SizedBox(
              height: cp.sizes.statMinHeight * 2,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: widget.initial,
                minimumDate: widget.firstDate,
                maximumDate: widget.lastDate,
                onDateTimeChanged: (d) => _value = d,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A switch with a title and an optional explanation, the whole row one
/// toggle. The switch is the platform's own (Req 21).
class CpSwitchRow extends StatelessWidget {
  const CpSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.help,
    this.switchKey,
  });

  final String title;
  final String? help;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    void toggle() {
      cpSelectionFeedback(context);
      onChanged?.call(!value);
    }

    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : toggle,
        borderRadius: cp.radii.sm,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
          child: Row(
            spacing: cp.space.md,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.xs / 2,
                  children: [
                    Text(
                      title,
                      style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                    ),
                    if (help != null)
                      Text(
                        help!,
                        style: cp.type.bodySmall.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: switchKey,
                value: value,
                onChanged: onChanged == null
                    ? null
                    : (v) {
                        cpSelectionFeedback(context);
                        onChanged!(v);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField({
    required this.semanticLabel,
    required this.onTap,
    required this.text,
    required this.muted,
    required this.hasError,
    this.leading,
    this.trailing,
  });

  final String semanticLabel;
  final VoidCallback? onTap;
  final String text;
  final bool muted;
  final bool hasError;
  final IconData? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final borderWidth = hasError ? cp.sizes.avatarRing : cp.sizes.hairline;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: cp.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: cp.radii.sm,
          side: BorderSide(
            color: hasError ? cp.colors.overdue : cp.colors.border,
            width: borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: cp.radii.sm,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
            child: Padding(
              padding: EdgeInsets.only(
                left: cp.space.md,
                right: trailing is IconButton ? 0 : cp.space.md,
              ),
              child: Row(
                spacing: cp.space.sm,
                children: [
                  if (leading != null)
                    Icon(
                      leading,
                      size: cp.sizes.iconMd - 2,
                      color: cp.colors.textMuted,
                    ),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        text,
                        style: cp.type.bodyMedium.copyWith(
                          color: muted ? cp.colors.textMuted : cp.colors.text,
                        ),
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
