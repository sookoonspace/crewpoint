import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/cp_button.dart';
import 'package:crewpoint_app/app/core/design/components/cp_fields.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// Opens a bottom sheet: a drag handle, an optional title, then [builder]'s
/// content, scrolling when tall and lifted above the keyboard.
///
/// Anything in the sheet that holds a `TextEditingController` must own it
/// in its own `State` and dispose it there: a sheet keeps rebuilding while
/// it closes, so disposing when this future completes crashes (#185).
Future<T?> showCpSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        CpSheet(title: title, child: builder(sheetContext)),
  );
}

/// The body of a bottom sheet. [showCpSheet] wraps content in it; use it
/// directly only to preview a sheet, as the Design gallery does.
class CpSheet extends StatelessWidget {
  const CpSheet({super.key, required this.child, this.title});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(cp.space.lg, 0, cp.space.lg, cp.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.lg,
          children: [
            if (title != null)
              Semantics(
                header: true,
                child: Text(
                  title!,
                  style: cp.type.titleLarge.copyWith(color: cp.colors.text),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// A dialog: a title, a message or content, and its buttons, laid out the
/// same on every platform. Show it with [showDialog].
class CpDialog extends StatelessWidget {
  const CpDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.content,
  });

  final String title;
  final String? message;
  final Widget? content;

  /// Usually a [CpButton.text] cancel, then the main action.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Dialog(
      backgroundColor: cp.colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: cp.radii.lg),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(cp.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.md,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: cp.type.titleLarge.copyWith(color: cp.colors.text),
              ),
            ),
            if (message != null)
              Text(
                message!,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              ),
            ?content,
            Padding(
              padding: EdgeInsets.only(top: cp.space.sm),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: cp.space.sm,
                runSpacing: cp.space.sm,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for one line of text in a dialog and returns it trimmed, or null
/// when cancelled. The dialog owns its text controller, which lives until
/// the dialog has finished closing (the #185 crash).
Future<String?> showCpTextPrompt({
  required BuildContext context,
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  String initial = '',
  String? help,
  FormFieldValidator<String>? validator,
  Key? fieldKey,
  Key? confirmKey,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => CpTextPrompt(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      initial: initial,
      help: help,
      validator: validator,
      fieldKey: fieldKey,
      confirmKey: confirmKey,
    ),
  );
}

/// The dialog [showCpTextPrompt] shows.
class CpTextPrompt extends StatefulWidget {
  const CpTextPrompt({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.cancelLabel,
    this.initial = '',
    this.help,
    this.validator,
    this.fieldKey,
    this.confirmKey,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String cancelLabel;
  final String initial;
  final String? help;
  final FormFieldValidator<String>? validator;
  final Key? fieldKey;
  final Key? confirmKey;

  @override
  State<CpTextPrompt> createState() => _CpTextPromptState();
}

class _CpTextPromptState extends State<CpTextPrompt> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // Only here, once the dialog has left the tree.
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return CpDialog(
      title: widget.title,
      content: Form(
        key: _formKey,
        child: CpTextField(
          label: widget.label,
          controller: _controller,
          fieldKey: widget.fieldKey,
          help: widget.help,
          validator: widget.validator,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirm(),
        ),
      ),
      actions: [
        CpButton.text(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        CpButton(
          key: widget.confirmKey,
          label: widget.confirmLabel,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
