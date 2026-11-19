import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Add / toggle / delete checklist items. Reorder is a backlog item.
///
/// Permissions are enforced by the parent passing the right callbacks:
///   * `onToggle` always available to authorized callers (assignee or higher)
///   * `onAdd` / `onDelete` / `onEditText` only wired for creator/owner/admin
///
/// A typed item not yet added counts as unsaved, so choosing another task
/// beside the list asks first (Spec #186 Req 23).
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
  void initState() {
    super.initState();
    _addController.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _addController
      ..removeListener(_changed)
      ..dispose();
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
    final cp = context.cp;
    final s = context.strings.tasks;
    final canAdd = widget.onAdd != null;
    final adding = canAdd && widget.items.length < widget.maxItems;

    final rows = <Widget>[
      for (final item in widget.items)
        _ChecklistRow(
          item: item,
          canEditText: widget.onEditText != null,
          canDelete: widget.onDelete != null,
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
      if (adding)
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: cp.space.lg,
            end: cp.space.xs,
            top: cp.space.sm,
            bottom: cp.space.sm,
          ),
          child: Row(
            spacing: cp.space.xs,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('tasks.detail.checklist.add'),
                  controller: _addController,
                  style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                  decoration: InputDecoration(
                    hintText: s.checklistAddHint,
                    counterText: '',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _submitNew(),
                  textInputAction: TextInputAction.done,
                  maxLength: widget.maxItemLength,
                ),
              ),
              IconButton(
                key: const Key('tasks.detail.checklist.add.submit'),
                tooltip: s.checklistAdd,
                onPressed: _submitNew,
                icon: Icon(
                  CpIcons.actionAddCircle,
                  size: cp.sizes.iconLg,
                  color: cp.colors.accent,
                ),
              ),
            ],
          ),
        ),
    ];

    return CpUnsavedChanges(
      dirty: _addController.text.trim().isNotEmpty,
      child: Column(
        key: const Key('tasks.detail.checklist'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: [
          CpSectionHeader(
            title: s.checklistHeading(widget.items.length, widget.maxItems),
          ),
          if (rows.isNotEmpty) CpCard(child: CpRowGroup(children: rows)),
        ],
      ),
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
    final cp = context.cp;
    final done = widget.item.isCompleted;
    return ConstrainedBox(
      key: Key('tasks.detail.checklist.item.${widget.item.id}'),
      constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
      child: Row(
        children: [
          Checkbox(
            key: Key('tasks.detail.checklist.item.${widget.item.id}.toggle'),
            value: done,
            activeColor: cp.colors.done,
            onChanged: widget.onToggle == null
                ? null
                : (value) => widget.onToggle!(value ?? false),
          ),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                    decoration: const InputDecoration(isDense: true),
                    onSubmitted: (_) => _commitEdit(),
                  )
                : GestureDetector(
                    onTap: widget.canEditText
                        ? () => setState(() => _editing = true)
                        : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: cp.space.sm),
                      child: Text(
                        widget.item.text,
                        style: cp.type.bodyMedium.copyWith(
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? cp.colors.textMuted : cp.colors.text,
                        ),
                      ),
                    ),
                  ),
          ),
          if (widget.canDelete)
            IconButton(
              key: Key('tasks.detail.checklist.item.${widget.item.id}.delete'),
              tooltip: context.strings.tasks.checklistRemove,
              onPressed: widget.onDelete,
              icon: Icon(
                CpIcons.actionClose,
                size: cp.sizes.iconSm,
                color: cp.colors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
