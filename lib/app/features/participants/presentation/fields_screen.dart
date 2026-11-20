import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/presentation/group_sheets.dart';

/// Custom fields and categories (Req 41, 42; route `fields`). Needs
/// `event.manage`. Fields are questions asked of each participant or group;
/// categories, such as Child and Adult, can be worked out from a birth date.
class FieldsScreen extends ConsumerWidget {
  const FieldsScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.fields;
    final words = event.words;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final title = strings.title(
      words.other('customField'),
      words.other('category').toLowerCase(),
    );
    Widget scaffold(Widget body) => AdminScaffold(title: title, body: body);
    if (!event.can(me, 'event.manage')) return scaffold(const NoAccessView());

    final fields = ref.watch(eventFieldsProvider(event.id));
    if (fields.hasError && !fields.hasValue) {
      return scaffold(
        LoadFailedView(
          onRetry: () => ref.invalidate(eventFieldsProvider(event.id)),
        ),
      );
    }
    if (!fields.hasValue) {
      return scaffold(
        CpLoadingState.rows(
          key: const Key('fields.loading'),
          semanticLabel: title,
        ),
      );
    }
    final cp = context.cp;
    final list = fields.value!;
    final categories = categoriesOf(event.settings);
    final archived = event.status == EventStatus.archived;
    Widget icon(IconData data) =>
        Icon(data, size: cp.sizes.iconMd, color: cp.colors.textMuted);
    CpListRow empty(String text, Key key) =>
        CpListRow(key: key, leading: icon(CpIcons.statusInfo), title: text);

    return scaffold(
      AdminList(
        listKey: const Key('fields.body'),
        children: [
          CpSectionHeader(
            title: strings.fieldsHeading(words.other('customField')),
            actionLabel: archived
                ? null
                : strings.addField(words.one('customField')),
            actionKey: const Key('fields.add'),
            onAction: archived
                ? null
                : () => FieldEditorSheet.show(
                    context,
                    event: event,
                    nextOrder: list.isEmpty ? 0 : list.last.order + 1,
                  ),
          ),
          CpCard(
            child: list.isEmpty
                ? empty(
                    strings.fieldsEmpty(words.other('customField')),
                    const Key('fields.empty'),
                  )
                : CpRowGroup(
                    children: [
                      for (final f in list)
                        CpListRow(
                          key: Key('fields.tile.${f.id}'),
                          leading: icon(
                            f.isPrivate ? CpIcons.lock : CpIcons.description,
                          ),
                          title: f.label,
                          subtitle: strings.fieldSummary(
                            f,
                            words.one('participant'),
                            words.one('group'),
                          ),
                          onTap: archived
                              ? null
                              : () => FieldEditorSheet.show(
                                  context,
                                  event: event,
                                  field: f,
                                  nextOrder: list.length,
                                ),
                        ),
                    ],
                  ),
          ),
          CpSectionHeader(
            title: strings.categoriesHeading(words.other('category')),
            actionLabel: archived
                ? null
                : strings.addCategory(words.one('category')),
            actionKey: const Key('fields.category.add'),
            onAction: archived
                ? null
                : () => CategoryEditorSheet.show(
                    context,
                    event: event,
                    categories: categories,
                  ),
          ),
          AdminNote(strings.categoriesHelp(words.other('category'))),
          CpCard(
            child: categories.isEmpty
                ? empty(
                    strings.categoriesEmpty(words.other('category')),
                    const Key('fields.categories.empty'),
                  )
                : CpRowGroup(
                    children: [
                      for (final c in categories)
                        CpListRow(
                          key: Key('fields.category.${c.id}'),
                          leading: icon(CpIcons.members),
                          title: c.name,
                          subtitle: strings.categorySummary(c),
                          onTap: archived
                              ? null
                              : () => CategoryEditorSheet.show(
                                  context,
                                  event: event,
                                  categories: categories,
                                  category: c,
                                ),
                        ),
                    ],
                  ),
          ),
          if (!archived && categories.isEmpty)
            CpButton.secondary(
              key: const Key('fields.category.preset'),
              label: strings.childAdultPreset,
              expand: true,
              onPressed: () => _savePreset(context, ref),
            ),
        ],
      ),
    );
  }

  /// The convention boundary (Req 42): 17 on the first day is a child, and
  /// 18 an adult.
  Future<void> _savePreset(BuildContext context, WidgetRef ref) async {
    final strings = context.strings.fields;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(participantRepositoryProvider).saveCategories(
        event.id,
        const [
          EventCategory(id: 'child', name: 'Child', maxAge: 17, isChild: true),
          EventCategory(id: 'adult', name: 'Adult', minAge: 18),
        ],
      );
      messenger.showSnackBar(SnackBar(content: Text(strings.saved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(strings.saveFailed)));
    }
  }
}

/// Adds or edits one custom field. A failed save keeps what was entered.
class FieldEditorSheet extends ConsumerStatefulWidget {
  const FieldEditorSheet({
    super.key,
    required this.event,
    this.field,
    this.nextOrder = 0,
  });

  final EventModel event;
  final CustomField? field;
  final int nextOrder;

  static Future<void> show(
    BuildContext context, {
    required EventModel event,
    CustomField? field,
    int nextOrder = 0,
  }) => showCpSheet<void>(
    context: context,
    title:
        field?.label ??
        context.strings.fields.newField(event.words.one('customField')),
    builder: (_) =>
        FieldEditorSheet(event: event, field: field, nextOrder: nextOrder),
  );

  @override
  ConsumerState<FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends ConsumerState<FieldEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _options;
  late FieldType _type;
  late bool _required;
  late FieldScope _scope;
  late FieldVisibility _visibility;
  bool _busy = false;
  String? _error;
  late final String _id;

  @override
  void initState() {
    super.initState();
    final f = widget.field;
    _id = f?.id ?? newGroupId();
    _label = TextEditingController(text: f?.label ?? '');
    _options = TextEditingController(text: (f?.options ?? const []).join('\n'));
    _type = f?.type ?? FieldType.text;
    _required = f?.required ?? false;
    _scope = f?.scope ?? FieldScope.participant;
    _visibility = f?.visibility ?? FieldVisibility.standard;
  }

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  bool get _hasOptions =>
      _type == FieldType.singleChoice || _type == FieldType.multiChoice;

  List<String> get _optionList => {
    for (final line in _options.text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  }.toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final strings = context.strings.fields;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(participantRepositoryProvider)
          .saveField(
            widget.event.id,
            CustomField(
              id: _id,
              label: _label.text.trim(),
              type: _type,
              options: _hasOptions ? _optionList : const [],
              required: _required,
              scope: _scope,
              visibility: _visibility,
              order: widget.field?.order ?? widget.nextOrder,
            ),
          );
      messenger.showSnackBar(SnackBar(content: Text(strings.saved)));
      navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final strings = context.strings.fields;
    final navigator = Navigator.of(context);
    final confirmed = await confirmAction(
      context,
      title: strings.deleteTitle(widget.field!.label),
      body: strings.deleteBody,
      action: strings.delete,
      confirmKey: const Key('fields.editor.deleteConfirm'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(participantRepositoryProvider)
          .deleteField(widget.event.id, widget.field!.id);
      navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickType() async {
    final cp = context.cp;
    final strings = context.strings.fields;
    final picked = await showCpSheet<FieldType>(
      context: context,
      title: strings.typeLabel,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final t in FieldType.values)
              CpListRow(
                key: Key('fields.editor.type.${t.name}'),
                title: strings.typeName(t),
                selected: t == _type,
                trailing: t == _type
                    ? Icon(
                        CpIcons.statusDone,
                        size: cp.sizes.iconMd,
                        color: cp.colors.accent,
                      )
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheet).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _type = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.fields;
    final words = widget.event.words;
    final participant = words.one('participant');
    final group = words.one('group');
    return Form(
      key: _formKey,
      child: Column(
        key: const Key('fields.editor'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          CpTextField(
            fieldKey: const Key('fields.editor.label'),
            label: strings.labelLabel,
            required: true,
            controller: _label,
            enabled: !_busy,
            validator: (v) {
              final label = v?.trim() ?? '';
              if (label.isEmpty) return strings.labelRequired;
              if (label.length > 80) {
                return context.strings.people.nameTooLong(80);
              }
              return null;
            },
          ),
          CpSelectField(
            fieldKey: const Key('fields.editor.type'),
            label: strings.typeLabel,
            value: strings.typeName(_type),
            onTap: _busy ? null : _pickType,
          ),
          if (_hasOptions)
            CpTextField(
              fieldKey: const Key('fields.editor.options'),
              label: strings.optionsLabel,
              help: strings.optionsHelp,
              required: true,
              controller: _options,
              enabled: !_busy,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              validator: (_) =>
                  _optionList.isEmpty ? strings.optionsRequired : null,
            ),
          CpSwitchRow(
            key: const Key('fields.editor.required'),
            title: strings.requiredLabel,
            value: _required,
            onChanged: _busy ? null : (on) => setState(() => _required = on),
          ),
          CpChoiceChips<FieldScope>(
            label: strings.scopeLabel(participant, group),
            required: true,
            choices: [
              for (final sc in FieldScope.values)
                CpChoice(
                  sc,
                  strings.scopeName(sc, participant, group),
                  key: Key('fields.editor.scope.${sc.name}'),
                ),
            ],
            selected: {_scope},
            onChanged: _busy
                ? null
                : (picked) {
                    if (picked.isNotEmpty) {
                      setState(() => _scope = picked.first);
                    }
                  },
          ),
          CpField(
            label: strings.visibilityLabel,
            child: CpCard(
              child: CpRowGroup(
                children: [
                  for (final (v, key, title, help) in [
                    (
                      FieldVisibility.standard,
                      'fields.editor.standard',
                      strings.visibilityStandard,
                      strings.visibilityStandardHelp,
                    ),
                    (
                      FieldVisibility.private,
                      'fields.editor.private',
                      strings.visibilityPrivate,
                      strings.visibilityPrivateHelp,
                    ),
                  ])
                    CpListRow(
                      key: Key(key),
                      title: title,
                      subtitle: help,
                      selected: _visibility == v,
                      trailing: _visibility == v
                          ? Icon(
                              CpIcons.statusDone,
                              size: cp.sizes.iconMd,
                              color: cp.colors.accent,
                            )
                          : const SizedBox.shrink(),
                      onTap: _busy
                          ? null
                          : () => setState(() => _visibility = v),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null)
            CpFieldError(_error!, key: const Key('fields.editor.error')),
          _EditorButtons(
            deleteKey: const Key('fields.editor.delete'),
            saveKey: const Key('fields.editor.save'),
            busy: _busy,
            onDelete: widget.field == null ? null : _delete,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

/// An editor's Delete, when there is something to delete, and Save.
class _EditorButtons extends StatelessWidget {
  const _EditorButtons({
    required this.deleteKey,
    required this.saveKey,
    required this.busy,
    required this.onDelete,
    required this.onSave,
  });

  final Key deleteKey;
  final Key saveKey;
  final bool busy;
  final VoidCallback? onDelete;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.fields;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: cp.space.sm,
      runSpacing: cp.space.sm,
      children: [
        if (onDelete != null)
          CpButton.text(
            key: deleteKey,
            label: strings.delete,
            icon: CpIcons.actionDelete,
            onPressed: busy ? null : onDelete,
          )
        else
          const SizedBox.shrink(),
        CpButton(
          key: saveKey,
          label: strings.save,
          busy: busy,
          onPressed: onSave,
        ),
      ],
    );
  }
}

/// Adds, edits or deletes one category, saving the event's whole list.
class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({
    super.key,
    required this.event,
    required this.categories,
    this.category,
  });

  final EventModel event;
  final List<EventCategory> categories;
  final EventCategory? category;

  static Future<void> show(
    BuildContext context, {
    required EventModel event,
    required List<EventCategory> categories,
    EventCategory? category,
  }) => showCpSheet<void>(
    context: context,
    title:
        category?.name ??
        context.strings.fields.addCategory(event.words.one('category')),
    builder: (_) => CategoryEditorSheet(
      event: event,
      categories: categories,
      category: category,
    ),
  );

  @override
  ConsumerState<CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late bool _child;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _name = TextEditingController(text: c?.name ?? '');
    _min = TextEditingController(text: c?.minAge?.toString() ?? '');
    _max = TextEditingController(text: c?.maxAge?.toString() ?? '');
    _child = c?.isChild ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  String? _validateAge(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null;
    final age = int.tryParse(text);
    return age == null || age < 0 || age > 130
        ? context.strings.fields.ageInvalid
        : null;
  }

  Future<void> _write(List<EventCategory> next) async {
    final strings = context.strings.fields;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(participantRepositoryProvider)
          .saveCategories(widget.event.id, next);
      navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _error = strings.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = EventCategory(
      id: widget.category?.id ?? newGroupId(),
      name: _name.text.trim(),
      minAge: int.tryParse(_min.text.trim()),
      maxAge: int.tryParse(_max.text.trim()),
      isChild: _child,
    );
    final exists = widget.categories.any((c) => c.id == updated.id);
    await _write([
      for (final c in widget.categories) c.id == updated.id ? updated : c,
      if (!exists) updated,
    ]);
  }

  Future<void> _delete() async {
    final strings = context.strings.fields;
    final confirmed = await confirmAction(
      context,
      title: strings.deleteTitle(widget.category!.name),
      body: strings.deleteBody,
      action: strings.delete,
      confirmKey: const Key('fields.category.deleteConfirm'),
    );
    if (!confirmed || !mounted) return;
    await _write([
      for (final c in widget.categories)
        if (c.id != widget.category!.id) c,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.fields;
    return Form(
      key: _formKey,
      child: Column(
        key: const Key('fields.categoryEditor'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          CpTextField(
            fieldKey: const Key('fields.category.name'),
            label: strings.nameLabel,
            required: true,
            controller: _name,
            enabled: !_busy,
            validator: (v) => (v?.trim() ?? '').isEmpty
                ? context.strings.people.nameRequired
                : null,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: cp.space.md,
            children: [
              Expanded(
                child: CpTextField(
                  fieldKey: const Key('fields.category.minAge'),
                  label: strings.minAgeLabel,
                  controller: _min,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  validator: _validateAge,
                ),
              ),
              Expanded(
                child: CpTextField(
                  fieldKey: const Key('fields.category.maxAge'),
                  label: strings.maxAgeLabel,
                  controller: _max,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  validator: _validateAge,
                ),
              ),
            ],
          ),
          Text(
            strings.agesHelp,
            style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
          ),
          CpSwitchRow(
            key: const Key('fields.category.child'),
            title: strings.childLabel,
            value: _child,
            onChanged: _busy ? null : (on) => setState(() => _child = on),
          ),
          if (_error != null)
            CpFieldError(_error!, key: const Key('fields.category.error')),
          _EditorButtons(
            deleteKey: const Key('fields.category.delete'),
            saveKey: const Key('fields.category.save'),
            busy: _busy,
            onDelete: widget.category == null ? null : _delete,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}
