import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Add / toggle / delete checklist items. Reorder is a backlog item.
///
/// Permissions are enforced by the parent passing the right callbacks:
///   * `onToggle` always available to authorized callers (assignee or higher)
///   * `onAdd` / `onDelete` / `onEditText` only wired for creator/owner/admin
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.items,
    this.onToggle,
    this.onAdd,
    this.onEditText,
    this.onDelete,
    this.maxItems = 25,
    this.maxItemLength = 120,
  });

  final List<ChecklistItem> items;
  final void Function(ChecklistItem item, bool isCompleted)? onToggle;
  final void Function(String id, String text)? onAdd;
  final void Function(ChecklistItem item, String text)? onEditText;
  final void Function(ChecklistItem item)? onDelete;
  final int maxItems;
  final int maxItemLength;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _submitNew() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    if (widget.items.length >= widget.maxItems) return;
    if (text.length > widget.maxItemLength) return;
    widget.onAdd?.call(const Uuid().v4(), text);
    _addController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.onAdd != null;
    final canEditMutate = widget.onEditText != null;
    final canDelete = widget.onDelete != null;

    return Column(
      key: const Key('tasks.detail.checklist'),
      crossAxisAlignment: .start,
      spacing: AppSpacing.sm,
      children: [
        Text(
          'Checklist (${widget.items.length}/${widget.maxItems})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final item in widget.items)
          _ChecklistRow(
            item: item,
            canEditText: canEditMutate,
            canDelete: canDelete,
            onToggle: widget.onToggle == null
                ? null
                : (value) => widget.onToggle!(item, value),
            onEditText: widget.onEditText == null
                ? null
                : (newText) => widget.onEditText!(item, newText),
            onDelete: widget.onDelete == null
                ? null
                : () => widget.onDelete!(item),
          ),
        if (canAdd && widget.items.length < widget.maxItems)
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('tasks.detail.checklist.add'),
                  controller: _addController,
                  decoration: InputDecoration(
                    hintText: context.strings.tasks.checklistAddHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submitNew(),
                  textInputAction: TextInputAction.done,
                  maxLength: widget.maxItemLength,
                ),
              ),
              IconButton(
                key: const Key('tasks.detail.checklist.add.submit'),
                onPressed: _submitNew,
                icon: const Icon(
                  AppIcons.actionAddCircle,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ChecklistRow extends StatefulWidget {
  const _ChecklistRow({
    required this.item,
    required this.canEditText,
    required this.canDelete,
    this.onToggle,
    this.onEditText,
    this.onDelete,
  });

  final ChecklistItem item;
  final bool canEditText;
  final bool canDelete;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<String>? onEditText;
  final VoidCallback? onDelete;

  @override
  State<_ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends State<_ChecklistRow> {
  bool _editing = false;
  late final TextEditingController _controller = TextEditingController(
    text: widget.item.text,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commitEdit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && text != widget.item.text) {
      widget.onEditText?.call(text);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('tasks.detail.checklist.item.${widget.item.id}'),
      children: [
        Checkbox(
          key: Key('tasks.detail.checklist.item.${widget.item.id}.toggle'),
          value: widget.item.isCompleted,
          onChanged: widget.onToggle == null
              ? null
              : (value) => widget.onToggle!(value ?? false),
        ),
        Expanded(
          child: _editing
              ? TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(isDense: true),
                  onSubmitted: (_) => _commitEdit(),
                )
              : GestureDetector(
                  onTap: widget.canEditText
                      ? () => setState(() => _editing = true)
                      : null,
                  child: Text(
                    widget.item.text,
                    style: TextStyle(
                      decoration: widget.item.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: widget.item.isCompleted
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
        ),
        if (widget.canDelete)
          IconButton(
            key: Key('tasks.detail.checklist.item.${widget.item.id}.delete'),
            onPressed: widget.onDelete,
            icon: Icon(
              AppIcons.actionClose,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
