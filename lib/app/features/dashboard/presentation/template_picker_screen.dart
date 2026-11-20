import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_template.dart';

/// `/dashboard/create` (Req 63; Spec #186): the first step of creating an
/// event is choosing a template. The person's own templates come first.
/// Choosing one opens the form for it.
class TemplatePickerScreen extends ConsumerWidget {
  const TemplatePickerScreen({super.key});

  static IconData iconFor(String icon) => iconForTemplate(icon);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.templates;
    final language = Localizations.localeOf(context).languageCode;
    final templates = ref.watch(templateCatalogueProvider);
    final mine = ref.watch(myTemplatesProvider).value ?? const [];
    final navigator = Navigator.of(context);

    Widget heading(String text) => Semantics(
      header: true,
      child: Text(
        text,
        style: cp.type.titleMedium.copyWith(color: cp.colors.text),
      ),
    );

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: strings.pickerTitle,
        leadingIcon: CpIcons.actionClose,
        leadingTooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
      body: switch (templates) {
        AsyncValue(:final value?) => ListView(
          key: const Key('events.create.templates'),
          padding: EdgeInsets.fromLTRB(
            cp.space.lg,
            cp.space.xs,
            cp.space.lg,
            cp.space.xxl,
          ),
          children: [
            ContentMaxWidth(
              maxWidth: cp.sizes.phoneColumn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: cp.space.md,
                children: [
                  Text(
                    strings.pickerHelp,
                    style: cp.type.bodyLarge.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                  // The person's own templates come first (Req 65).
                  if (mine.isNotEmpty) ...[
                    SizedBox(height: cp.space.sm),
                    heading(strings.mineHeading),
                    for (final t in mine)
                      _TemplateCard(
                        template: t,
                        language: language,
                        saved: true,
                        baseName: value
                            .where((b) => b.id == t.baseTemplateId)
                            .firstOrNull
                            ?.name(language),
                      ),
                    SizedBox(height: cp.space.sm),
                    heading(strings.systemHeading),
                  ],
                  for (final t in value)
                    _TemplateCard(template: t, language: language),
                ],
              ),
            ),
          ],
        ),
        AsyncValue(error: _?) => CpErrorState(
          key: const Key('events.create.templates.error'),
          title: strings.loadFailed,
          retryLabel: strings.retry,
          retryKey: const Key('events.create.templates.retry'),
          onRetry: () => ref.invalidate(templateCatalogueProvider),
        ),
        _ => CpLoadingState.rows(
          key: const Key('events.create.templates.loading'),
          semanticLabel: strings.pickerTitle,
        ),
      },
    );
  }
}

/// One template as a card: its icon, name, what it is for, and "Just a
/// title and a date" for the quick ones. A saved template can be deleted.
class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({
    required this.template,
    required this.language,
    this.saved = false,
    this.baseName,
  });

  final EventTemplateInfo template;
  final String language;

  /// One of the person's own templates, which they may delete.
  final bool saved;

  /// The name of the template a saved one started from.
  final String? baseName;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final strings = context.strings.templates;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: strings.deleteMineTitle(template.name(language)),
        message: strings.deleteMineBody,
        actions: [
          CpButton.text(
            key: const Key('events.create.mine.deleteCancel'),
            label: strings.cancel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('events.create.mine.deleteConfirm'),
            label: strings.delete,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (sure != true) return;
    final me = ref.read(currentUserIdProvider);
    if (me == null) return;
    await ref
        .read(firestoreProvider)
        .doc('users/$me/templates/${template.id}')
        .delete();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.templates;
    final description = template.description(language);
    final subtitle = [
      if (saved && baseName != null) strings.basedOn(baseName!),
      if (description.isNotEmpty) description,
    ].join(' · ');

    final icon = Container(
      width: cp.sizes.iconTile,
      height: cp.sizes.iconTile,
      decoration: BoxDecoration(
        color: cp.colors.accentSoft,
        borderRadius: cp.radii.sm,
      ),
      child: Icon(
        TemplatePickerScreen.iconFor(template.icon),
        size: cp.sizes.iconMd,
        color: cp.colors.accent,
      ),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.xs,
      children: [
        Text(
          template.name(language),
          style: cp.type.titleMedium.copyWith(color: cp.colors.text),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
        if (template.fastPath)
          Padding(
            padding: EdgeInsets.only(top: cp.space.xs),
            child: CpTag(label: strings.quick),
          ),
      ],
    );
    final Widget trailing = saved
        ? IconButton(
            key: Key('events.create.mine.${template.id}.delete'),
            tooltip: strings.deleteMine,
            icon: Icon(
              CpIcons.actionDelete,
              size: cp.sizes.iconMd,
              color: cp.colors.textMuted,
            ),
            onPressed: () => _delete(context, ref),
          )
        : Padding(
            padding: EdgeInsets.only(top: cp.space.sm),
            child: Icon(
              CpIcons.chevronRight,
              size: cp.sizes.iconMd,
              color: cp.colors.textMuted,
            ),
          );

    return CpCard(
      // Not merged, so a saved template's Delete stays its own button.
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key(
              saved
                  ? 'events.create.mine.${template.id}'
                  : 'events.create.template.${template.id}',
            ),
            borderRadius: cp.radii.md,
            onTap: () => context.push(
              saved
                  ? '/dashboard/create/mine/${template.id}'
                  : '/dashboard/create/${template.id}',
            ),
            child: Padding(
              padding: EdgeInsets.all(cp.space.lg),
              child: LayoutBuilder(
                builder: (context, box) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  // Large text: the icon and action go above the words, so
                  // the name and description keep the card's full width.
                  if (box.maxWidth / scale < 260) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: cp.space.sm,
                      children: [
                        Row(children: [icon, const Spacer(), trailing]),
                        texts,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: cp.space.md,
                    children: [
                      icon,
                      Expanded(child: texts),
                      trailing,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
