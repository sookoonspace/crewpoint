import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
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
    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: body,
    );
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
        const Center(
          child: CircularProgressIndicator(key: Key('fields.loading')),
        ),
      );
    }
    final list = fields.value!;
    final categories = categoriesOf(event.settings);
    final theme = Theme.of(context);
    final archived = event.status == EventStatus.archived;

    return scaffold(
      ListView(
        key: const Key('fields.body'),
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.lg,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  strings.fieldsHeading(words.other('customField')),
                  style: theme.textTheme.titleMedium,
                ),
                if (list.isEmpty)
                  Text(
                    strings.fieldsEmpty(words.other('customField')),
                    key: const Key('fields.empty'),
                  ),
                for (final f in list)
                  ListTile(
                    key: Key('fields.tile.${f.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      f.isPrivate ? AppIcons.lock : AppIcons.actionEdit,
                    ),
                    title: Text(f.label),
                    subtitle: Text(
                      strings.fieldSummary(
                        f,
                        words.one('participant'),
                        words.one('group'),
                      ),
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
                if (!archived)
                  OutlinedButton.icon(
                    key: const Key('fields.add'),
                    onPressed: () => FieldEditorSheet.show(
                      context,
                      event: event,
                      nextOrder: list.isEmpty ? 0 : list.last.order + 1,
                    ),
                    icon: const Icon(AppIcons.actionAdd),
                    label: Text(strings.addField(words.one('customField'))),
                  ),
                const Divider(height: AppSpacing.xxl),
                Text(
                  strings.categoriesHeading(words.other('category')),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  strings.categoriesHelp(words.other('category')),
                  style: theme.textTheme.bodySmall,
                ),
                if (categories.isEmpty)
                  Text(
                    strings.categoriesEmpty(words.other('category')),
                    key: const Key('fields.categories.empty'),
                  ),
                for (final c in categories)
                  ListTile(
                    key: Key('fields.category.${c.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.members),
                    title: Text(c.name),
                    subtitle: Text(strings.categorySummary(c)),
                    onTap: archived
                        ? null
                        : () => CategoryEditorSheet.show(
                            context,
                            event: event,
                            categories: categories,
                            category: c,
                          ),
                  ),
                if (!archived && categories.isEmpty)
                  OutlinedButton(
                    key: const Key('fields.category.preset'),
                    onPressed: () => _savePreset(context, ref),
                    child: Text(strings.childAdultPreset),
                  ),
                if (!archived)
                  OutlinedButton.icon(
                    key: const Key('fields.category.add'),
                    onPressed: () => CategoryEditorSheet.show(
                      context,
                      event: event,
                      categories: categories,
                    ),
                    icon: const Icon(AppIcons.actionAdd),
                    label: Text(strings.addCategory(words.one('category'))),
                  ),
              ],
            ),
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
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.fields;
    final words = widget.event.words;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          key: const Key('fields.editor'),
          shrinkWrap: true,
          children: [
            Text(
              widget.field?.label ?? strings.newField(words.one('customField')),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('fields.editor.label'),
              controller: _label,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: strings.labelLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final label = v?.trim() ?? '';
                if (label.isEmpty) return strings.labelRequired;
                if (label.length > 80) {
                  return context.strings.people.nameTooLong(80);
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<FieldType>(
              key: const Key('fields.editor.type'),
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(
                labelText: strings.typeLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final t in FieldType.values)
                  DropdownMenuItem(value: t, child: Text(strings.typeName(t))),
              ],
              onChanged: _busy ? null : (t) => setState(() => _type = t!),
            ),
            if (_hasOptions) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('fields.editor.options'),
                controller: _options,
                enabled: !_busy,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: strings.optionsLabel,
                  helperText: strings.optionsHelp,
                  border: const OutlineInputBorder(),
                ),
                validator: (_) =>
                    _optionList.isEmpty ? strings.optionsRequired : null,
              ),
            ],
            SwitchListTile(
              key: const Key('fields.editor.required'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.requiredLabel),
              value: _required,
              onChanged: _busy ? null : (on) => setState(() => _required = on),
            ),
            Text(
              strings.scopeLabel(words.one('participant'), words.one('group')),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<FieldScope>(
              groupValue: _scope,
              onChanged: (v) {
                if (v != null && !_busy) setState(() => _scope = v);
              },
              child: Column(
                key: const Key('fields.editor.scope'),
                children: [
                  for (final sc in FieldScope.values)
                    RadioListTile<FieldScope>(
                      key: Key('fields.editor.scope.${sc.name}'),
                      contentPadding: EdgeInsets.zero,
                      value: sc,
                      title: Text(
                        strings.scopeName(
                          sc,
                          words.one('participant'),
                          words.one('group'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(strings.visibilityLabel, style: theme.textTheme.titleSmall),
            RadioGroup<FieldVisibility>(
              groupValue: _visibility,
              onChanged: (v) {
                if (v != null && !_busy) setState(() => _visibility = v);
              },
              child: Column(
                children: [
                  RadioListTile<FieldVisibility>(
                    key: const Key('fields.editor.standard'),
                    contentPadding: EdgeInsets.zero,
                    value: FieldVisibility.standard,
                    title: Text(strings.visibilityStandard),
                    subtitle: Text(strings.visibilityStandardHelp),
                  ),
                  RadioListTile<FieldVisibility>(
                    key: const Key('fields.editor.private'),
                    contentPadding: EdgeInsets.zero,
                    value: FieldVisibility.private,
                    title: Text(strings.visibilityPrivate),
                    subtitle: Text(strings.visibilityPrivateHelp),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('fields.editor.error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                if (widget.field != null)
                  TextButton.icon(
                    key: const Key('fields.editor.delete'),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(AppIcons.actionDelete),
                    label: Text(strings.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                FilledButton(
                  key: const Key('fields.editor.save'),
                  onPressed: _busy ? null : _save,
                  child: Text(strings.save),
                ),
              ],
            ),
          ],
        ),
      ),
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
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
    final strings = context.strings.fields;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          key: const Key('fields.categoryEditor'),
          shrinkWrap: true,
          children: [
            TextFormField(
              key: const Key('fields.category.name'),
              controller: _name,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: strings.nameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim() ?? '').isEmpty
                  ? context.strings.people.nameRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('fields.category.minAge'),
                    controller: _min,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.minAgeLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateAge,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    key: const Key('fields.category.maxAge'),
                    controller: _max,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.maxAgeLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateAge,
                  ),
                ),
              ],
            ),
            Text(strings.agesHelp, style: theme.textTheme.bodySmall),
            SwitchListTile(
              key: const Key('fields.category.child'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.childLabel),
              value: _child,
              onChanged: _busy ? null : (on) => setState(() => _child = on),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('fields.category.error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                if (widget.category != null)
                  TextButton.icon(
                    key: const Key('fields.category.delete'),
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(AppIcons.actionDelete),
                    label: Text(strings.delete),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                FilledButton(
                  key: const Key('fields.category.save'),
                  onPressed: _busy ? null : _save,
                  child: Text(strings.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
