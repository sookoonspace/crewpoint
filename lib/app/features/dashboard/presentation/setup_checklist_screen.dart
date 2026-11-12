import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart'
    show eventFieldsProvider, participantCountProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `setup` (Req 64): optional follow-up setup after creating an event from a
/// larger template. Each step opens the screen that does it and is ticked
/// once done; all of it can be skipped and finished later from Event
/// settings.
class SetupChecklistScreen extends ConsumerWidget {
  const SetupChecklistScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.templates;
    final theme = Theme.of(context);
    final base = '/dashboard/event/${event.id}';
    final readsPeople = event.can(
      ref.watch(currentUserIdProvider) ?? '',
      'participants.read',
    );

    final steps =
        <
          ({
            String id,
            IconData icon,
            String title,
            String help,
            bool done,
            String route,
          })
        >[
          (
            id: 'dates',
            icon: AppIcons.calendar,
            title: strings.stepDates,
            help: strings.stepDatesHelp,
            done: event.startDate != null,
            route: '$base/edit',
          ),
          (
            id: 'venues',
            icon: AppIcons.place,
            title: strings.stepVenues,
            help: strings.stepVenuesHelp,
            done: event.venues.isNotEmpty,
            route: '$base/settings',
          ),
          if (event.isModuleOn('schedule'))
            (
              id: 'schedule',
              icon: AppIcons.schedule,
              title: strings.stepSchedule,
              help: strings.stepScheduleHelp,
              done:
                  ref.watch(sessionListProvider(event.id)).value?.isNotEmpty ??
                  false,
              route: '$base/schedule',
            ),
          (
            id: 'fields',
            icon: AppIcons.actionEdit,
            title: strings.stepFields,
            help: strings.stepFieldsHelp,
            done:
                ref.watch(eventFieldsProvider(event.id)).value?.isNotEmpty ??
                false,
            route: '$base/fields',
          ),
          if (readsPeople)
            (
              id: 'people',
              icon: AppIcons.members,
              title: strings.stepPeople(event.words.other('participant')),
              help: strings.stepPeopleHelp(event.words.other('participant')),
              done:
                  (ref.watch(participantCountProvider(event.id)).value ?? 0) >
                  0,
              route: '$base/people',
            ),
        ];

    void close() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(base);
      }
    }

    final padding = Breakpoints.screenHorizontalPadding(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.setupTitle), elevation: 0),
      body: ContentMaxWidth(
        maxWidth: 640,
        child: ListView(
          key: const Key('setup.list'),
          padding: EdgeInsets.fromLTRB(padding, AppSpacing.md, padding, 48),
          children: [
            Text(strings.setupHelp, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            for (final step in steps)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  key: Key('setup.step.${step.id}'),
                  minVerticalPadding: AppSpacing.md,
                  leading: Icon(step.icon, color: theme.colorScheme.primary),
                  title: Text(step.title),
                  subtitle: Text(step.help),
                  trailing: Semantics(
                    label: step.done ? strings.stepComplete : strings.stepToDo,
                    child: Icon(
                      step.done ? AppIcons.statusDone : AppIcons.chevronRight,
                      key: Key(
                        'setup.step.${step.id}.${step.done ? 'done' : 'todo'}',
                      ),
                      color: step.done
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => context.push(step.route),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('setup.skip'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: close,
              child: Text(
                steps.every((s) => s.done)
                    ? strings.setupDone
                    : strings.setupSkip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
