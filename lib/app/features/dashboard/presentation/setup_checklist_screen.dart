import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart'
    show eventFieldsProvider, participantCountProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `setup` (Req 64; Spec #186): optional follow-up setup after creating an event from a
/// larger template. Each step opens the screen that does it and is ticked
/// once done; all of it can be skipped and finished later from Event
/// settings.
class SetupChecklistScreen extends ConsumerWidget {
  const SetupChecklistScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.templates;
    final cp = context.cp;
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
            icon: CpIcons.calendar,
            title: strings.stepDates,
            help: strings.stepDatesHelp,
            done: event.startDate != null,
            route: '$base/edit',
          ),
          (
            id: 'venues',
            icon: CpIcons.place,
            title: strings.stepVenues,
            help: strings.stepVenuesHelp,
            done: event.venues.isNotEmpty,
            route: '$base/settings',
          ),
          if (event.isModuleOn('schedule'))
            (
              id: 'schedule',
              icon: CpIcons.schedule,
              title: strings.stepSchedule,
              help: strings.stepScheduleHelp,
              done:
                  ref.watch(sessionListProvider(event.id)).value?.isNotEmpty ??
                  false,
              route: '$base/schedule',
            ),
          (
            id: 'fields',
            icon: CpIcons.actionEdit,
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
              icon: CpIcons.members,
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

    final allDone = steps.every((s) => s.done);
    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: strings.setupTitle,
        leadingIcon: CpIcons.actionClose,
        leadingTooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onLeading: close,
      ),
      body: ListView(
        key: const Key('setup.list'),
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
              spacing: cp.space.lg,
              children: [
                Text(
                  strings.setupHelp,
                  style: cp.type.bodyLarge.copyWith(color: cp.colors.textMuted),
                ),
                CpCard(
                  child: CpRowGroup(
                    children: [
                      for (final step in steps)
                        _StepRow(
                          key: Key('setup.step.${step.id}'),
                          id: step.id,
                          icon: step.icon,
                          title: step.title,
                          help: step.help,
                          done: step.done,
                          onTap: () => context.push(step.route),
                        ),
                    ],
                  ),
                ),
                CpButton(
                  key: const Key('setup.skip'),
                  label: allDone ? strings.setupDone : strings.setupSkip,
                  variant: allDone
                      ? CpButtonVariant.primary
                      : CpButtonVariant.secondary,
                  expand: true,
                  onPressed: close,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One step: its icon, what it is and why, and Done in green with its
/// icon, or a chevron read as "Not yet". At large text the status goes
/// under the words, so they keep the row's width.
class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.help,
    required this.done,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String title;
  final String help;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.templates;
    final status = done
        ? CpStatusChip(
            key: Key('setup.step.$id.done'),
            status: CpStatus.done,
            label: strings.stepComplete,
          )
        : Semantics(
            label: strings.stepToDo,
            child: Icon(
              CpIcons.chevronRight,
              key: Key('setup.step.$id.todo'),
              size: cp.sizes.iconMd,
              color: cp.colors.textMuted,
            ),
          );
    final tile = Container(
      width: cp.sizes.iconTile,
      height: cp.sizes.iconTile,
      decoration: BoxDecoration(
        color: cp.colors.accentSoft,
        borderRadius: cp.radii.sm,
      ),
      child: Icon(icon, size: cp.sizes.iconMd, color: cp.colors.accent),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.xs / 2,
      children: [
        Text(title, style: cp.type.titleSmall.copyWith(color: cp.colors.text)),
        Text(
          help,
          style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
        ),
      ],
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: cp.space.lg,
                  vertical: cp.space.md,
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    if (box.maxWidth / scale < 260) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: cp.space.sm,
                        children: [
                          Row(
                            children: [tile, const Spacer(), if (!done) status],
                          ),
                          words,
                          if (done) status,
                        ],
                      );
                    }
                    return Row(
                      spacing: cp.space.md,
                      children: [
                        tile,
                        Expanded(child: words),
                        status,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
