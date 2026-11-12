import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/dashboard/create` (Req 63): the first step of creating an event is
/// choosing a template. Choosing one opens the form for it.
class TemplatePickerScreen extends ConsumerWidget {
  const TemplatePickerScreen({super.key});

  static IconData iconFor(String icon) => switch (icon) {
    'celebration' => AppIcons.templateCelebration,
    'heart' => AppIcons.templateHeart,
    'bat' => AppIcons.templateBat,
    'flag' => AppIcons.templateFlag,
    'groups' => AppIcons.templateGroups,
    _ => AppIcons.templateAdd,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.templates;
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final templates = ref.watch(templateCatalogueProvider);
    final padding = Breakpoints.screenHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.pickerTitle), elevation: 0),
      body: ContentMaxWidth(
        maxWidth: 720,
        child: switch (templates) {
          AsyncValue(:final value?) => ListView(
            key: const Key('events.create.templates'),
            padding: EdgeInsets.fromLTRB(padding, AppSpacing.md, padding, 48),
            children: [
              Text(strings.pickerHelp, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              for (final t in value)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _TemplateCard(template: t, language: language),
                ),
            ],
          ),
          AsyncValue(error: _?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.md,
                children: [
                  Text(
                    strings.loadFailed,
                    key: const Key('events.create.templates.error'),
                    textAlign: TextAlign.center,
                  ),
                  FilledButton.icon(
                    key: const Key('events.create.templates.retry'),
                    onPressed: () => ref.invalidate(templateCatalogueProvider),
                    icon: const Icon(AppIcons.actionRetry),
                    label: Text(strings.retry),
                  ),
                ],
              ),
            ),
          ),
          _ => const Center(
            child: CircularProgressIndicator(
              key: Key('events.create.templates.loading'),
            ),
          ),
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.language});

  final EventTemplateInfo template;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings.templates;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        key: Key('events.create.template.${template.id}'),
        minVerticalPadding: AppSpacing.md,
        leading: Icon(
          TemplatePickerScreen.iconFor(template.icon),
          color: theme.colorScheme.primary,
        ),
        title: Text(template.name(language)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.description(language)),
            if (template.fastPath)
              Text(
                strings.quick,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: const Icon(AppIcons.chevronRight),
        onTap: () => context.push('/dashboard/create/${template.id}'),
      ),
    );
  }
}
