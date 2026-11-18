import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// How the gallery is shown (Spec #186 Req 17).
enum DesignGalleryVariant {
  light('Light'),
  dark('Dark'),
  largeText('200% text');

  const DesignGalleryVariant(this.label);

  final String label;
}

/// The parts of the gallery, each pictured on its own by the golden tests
/// and in `docs/design/design-system.md`.
enum DesignGallerySection {
  colours('Colours'),
  type('Type'),
  cardsAndRows('Cards and rows'),
  chipsAndHeaders('Chips and section headers'),
  stats('Stat cards and progress rings'),
  people('Avatars'),
  states('Empty, loading and error states'),
  topBar('Top bar'),
  buttons('Buttons'),
  fields('Fields'),
  choices('Choice chips and segmented choices'),
  sheetsAndDialogs('Sheets and dialogs'),
  cover('Event cover');

  const DesignGallerySection(this.title);

  final String title;
}

/// Applies [variant]'s theme and text size to [child]: light, dark, or
/// light at 200% text.
class DesignGalleryFrame extends StatelessWidget {
  const DesignGalleryFrame({
    super.key,
    required this.variant,
    required this.child,
  });

  final DesignGalleryVariant variant;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = variant == DesignGalleryVariant.dark
        ? CpTheme.dark()
        : CpTheme.light();
    return Theme(
      data: theme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: variant == DesignGalleryVariant.largeText
              ? const TextScaler.linear(2)
              : TextScaler.noScaling,
        ),
        child: Material(color: theme.scaffoldBackgroundColor, child: child),
      ),
    );
  }
}

/// Every design-system component with sample content. Plain widgets only,
/// so it renders in the dev build's Design gallery and in golden tests.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key, this.sections = DesignGallerySection.values});

  final List<DesignGallerySection> sections;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Padding(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.xl,
        children: [
          for (final section in sections)
            Column(
              key: Key('dev.gallery.${section.name}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.md,
              children: [
                Text(
                  section.title.toUpperCase(),
                  style: cp.type.labelSmall.copyWith(
                    color: cp.colors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                _section(section),
              ],
            ),
        ],
      ),
    );
  }

  Widget _section(DesignGallerySection section) => switch (section) {
    DesignGallerySection.colours => const _Colours(),
    DesignGallerySection.type => const _Type(),
    DesignGallerySection.cardsAndRows => const _CardsAndRows(),
    DesignGallerySection.chipsAndHeaders => const _ChipsAndHeaders(),
    DesignGallerySection.stats => const _Stats(),
    DesignGallerySection.people => const _People(),
    DesignGallerySection.states => const _States(),
    DesignGallerySection.topBar => const _TopBar(),
    DesignGallerySection.buttons => const _Buttons(),
    DesignGallerySection.fields => const _Fields(),
    DesignGallerySection.choices => const _Choices(),
    DesignGallerySection.sheetsAndDialogs => const _SheetsAndDialogs(),
    DesignGallerySection.cover => const _Cover(),
  };
}

void _noop() {}

class _Colours extends StatelessWidget {
  const _Colours();

  @override
  Widget build(BuildContext context) {
    final c = context.cp.colors;
    final space = context.cp.space;
    final swatches = <(String, Color)>[
      ('background', c.background),
      ('surface', c.surface),
      ('fill', c.fill),
      ('border', c.border),
      ('text', c.text),
      ('textMuted', c.textMuted),
      ('accent', c.accent),
      ('accentSoft', c.accentSoft),
      ('banner', c.banner),
      ('done', c.done),
      ('due', c.due),
      ('overdue', c.overdue),
    ];
    return Wrap(
      spacing: space.sm,
      runSpacing: space.sm,
      children: [
        for (final (name, color) in swatches)
          SizedBox(
            width: context.cp.sizes.statMinHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: space.xs,
              children: [
                Container(
                  height: context.cp.sizes.tapMin,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: context.cp.radii.sm,
                    border: Border.all(
                      color: c.border,
                      width: context.cp.sizes.hairline,
                    ),
                  ),
                ),
                Text(
                  name,
                  style: context.cp.type.labelSmall.copyWith(
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Type extends StatelessWidget {
  const _Type();

  @override
  Widget build(BuildContext context) {
    final t = context.cp.type;
    final color = context.cp.colors.text;
    final styles = <(String, TextStyle)>[
      ('headlineLarge · page title', t.headlineLarge),
      ('titleLarge · section', t.titleLarge),
      ('titleSmall · row title', t.titleSmall),
      ('bodyMedium · body', t.bodyMedium),
      ('bodySmall · subtitle', t.bodySmall),
      ('labelMedium · chip', t.labelMedium),
      (r'stat · $4,320', t.stat),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.cp.space.sm,
      children: [
        for (final (name, style) in styles)
          Text(name, style: style.copyWith(color: color)),
      ],
    );
  }
}

class _CardsAndRows extends StatelessWidget {
  const _CardsAndRows();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    Widget time(String t, String ampm) => SizedBox(
      width: cp.sizes.statMinHeight / 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: cp.type.titleSmall.copyWith(color: cp.colors.text)),
          Text(
            ampm,
            style: cp.type.labelSmall.copyWith(color: cp.colors.textMuted),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        CpCard(
          child: CpRowGroup(
            children: [
              CpListRow(
                leading: time('9:00', 'AM'),
                title: 'Registration opens',
                subtitle: 'Main hall',
                onTap: _noop,
              ),
              CpListRow(
                leading: time('10:30', 'AM'),
                title: 'Opening session',
                subtitle: 'Ballroom A · Everyone',
                onTap: _noop,
              ),
              const CpListRow(
                leading: CpAvatar(name: 'Kabir Mehta'),
                title: 'Kabir Mehta',
                subtitle: 'Mehta · Child · 6–12',
                selected: true,
              ),
            ],
          ),
        ),
        CpCard(
          padding: EdgeInsets.all(cp.space.lg),
          child: Text(
            'A card with free content uses large padding.',
            style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
          ),
        ),
      ],
    );
  }
}

class _ChipsAndHeaders extends StatelessWidget {
  const _ChipsAndHeaders();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        Wrap(
          spacing: cp.space.sm,
          runSpacing: cp.space.sm,
          children: const [
            CpStatusChip(status: CpStatus.overdue, label: 'Overdue'),
            CpStatusChip(status: CpStatus.due, label: 'Due Fri'),
            CpStatusChip(status: CpStatus.done, label: 'Done'),
            CpStatusChip(status: CpStatus.done, label: 'Paid'),
          ],
        ),
        Wrap(
          spacing: cp.space.sm,
          runSpacing: cp.space.sm,
          children: const [
            CpTag(label: 'Published'),
            CpTag(label: 'Live', dot: true),
            CpTag(label: 'Draft', tone: CpTagTone.quiet),
            CpTag(
              label: 'Hidden draft',
              tone: CpTagTone.quiet,
              icon: CpIcons.lock,
            ),
          ],
        ),
        const CpSectionHeader(
          title: 'Up next',
          actionLabel: 'Schedule',
          onAction: _noop,
        ),
        const CpSectionHeader(title: '148 people', trailingText: '41 groups'),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        const CpStatGrid(
          children: [
            CpStatCard(
              icon: CpIcons.members,
              label: 'People',
              value: '148',
              caption: '41 groups',
            ),
            CpStatCard(
              icon: CpIcons.tasks,
              label: 'Tasks',
              value: '18/26',
              progress: 18 / 26,
              progressLabel: '18 of 26 done',
              caption: '2 overdue',
            ),
            CpStatCard(
              icon: CpIcons.budget,
              label: 'Budget',
              value: r'$4,320',
              caption: r'of $6,000',
            ),
          ],
        ),
        Row(
          spacing: cp.space.lg,
          children: [
            const CpProgressRing(value: 0, semanticLabel: 'None done'),
            const CpProgressRing(value: 0.5, semanticLabel: 'Half done'),
            CpProgressRing(
              value: 1,
              semanticLabel: 'All done',
              size: cp.sizes.ringLg,
            ),
          ],
        ),
      ],
    );
  }
}

class _People extends StatelessWidget {
  const _People();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.md,
      children: [
        Row(
          spacing: cp.space.md,
          children: const [
            CpAvatar(name: 'Asha Singh', size: CpAvatarSize.small),
            CpAvatar(name: 'Ravi Patel'),
            CpAvatar(name: 'Kabir Mehta', size: CpAvatarSize.large),
            CpAvatar(name: '', semanticLabel: 'Unnamed person'),
          ],
        ),
        const CpAvatarStack(
          names: [
            'Asha Singh',
            'Ravi Patel',
            'Mira Kapoor',
            'Jai Lal',
            'Neha Mehta',
            'Priya Shah',
          ],
          semanticLabel: '148 attending',
        ),
      ],
    );
  }
}

class _States extends StatelessWidget {
  const _States();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: const [
        CpCard(
          child: CpEmptyState(
            icon: CpIcons.members,
            title: 'No people yet',
            message: 'Add people attending, with or without an account.',
            actionLabel: 'Add person',
            onAction: _noop,
          ),
        ),
        CpCard(
          child: CpErrorState(
            title: "Couldn't load",
            message: 'This list needs a connection, so check yours.',
            retryLabel: 'Try again',
            onRetry: _noop,
          ),
        ),
        CpLoadingState.rows(semanticLabel: 'Loading', rows: 2),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: const [
        CpTopBar(
          title: 'People',
          leadingTooltip: 'Back',
          onLeading: _noop,
          actions: [
            CpTopBarAction(
              icon: CpIcons.importFile,
              tooltip: 'Import',
              onPressed: _noop,
            ),
            CpTopBarAction(
              icon: CpIcons.actionAdd,
              tooltip: 'Add',
              onPressed: _noop,
              primary: true,
            ),
          ],
        ),
        CpTopBar(
          title: 'New group',
          leadingIcon: CpIcons.actionClose,
          leadingTooltip: 'Close',
          onLeading: _noop,
        ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        Wrap(
          spacing: cp.space.sm,
          runSpacing: cp.space.sm,
          children: const [
            CpButton(label: 'Save', onPressed: _noop),
            CpButton.secondary(
              label: 'Add people',
              icon: CpIcons.memberAdd,
              onPressed: _noop,
            ),
            CpButton.text(label: 'Cancel', onPressed: _noop),
            CpButton.destructive(label: 'Remove', onPressed: _noop),
          ],
        ),
        Wrap(
          spacing: cp.space.sm,
          runSpacing: cp.space.sm,
          children: const [
            CpButton(label: 'Saving', busy: true, onPressed: _noop),
            CpButton(label: 'Save', onPressed: null),
          ],
        ),
        const CpButton(label: 'Save group', expand: true, onPressed: _noop),
      ],
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          const CpTextField(
            label: 'Name',
            required: true,
            hint: 'Full name',
            help: 'As it should appear on a badge.',
          ),
          const CpTextField(
            label: 'Email',
            labelIcon: CpIcons.lock,
            error: 'Enter a valid email.',
          ),
          const CpSelectField(label: 'Group', value: 'Mehta', onTap: _noop),
          CpDateField(
            label: 'Birth date',
            labelIcon: CpIcons.lock,
            value: DateTime(2018, 3, 14),
            onChanged: (_) {},
            format: (d) => '14 March ${d.year}',
            firstDate: DateTime(1900),
            lastDate: DateTime(2030),
            clearLabel: 'Clear birth date',
            help: 'Sets the age band: 6–12.',
          ),
          CpSwitchRow(
            title: 'Child',
            help: 'Children have no account.',
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          CpChoiceChips<String>(
            label: 'Diet',
            required: true,
            choices: const [
              CpChoice('veg', 'Veg'),
              CpChoice('jain', 'Jain'),
              CpChoice('nonVeg', 'Non-veg'),
            ],
            selected: const {'veg'},
            onChanged: (_) {},
          ),
          CpChoiceChips<String>(
            label: 'Interested in',
            multiple: true,
            help: 'Choose any.',
            choices: const [
              CpChoice('workshops', 'Workshops'),
              CpChoice('sports', 'Sports'),
              CpChoice('music', 'Music'),
            ],
            selected: const {'workshops', 'sports'},
            onChanged: (_) {},
          ),
          CpChoiceChips<String>(
            label: 'T-shirt size',
            required: true,
            error: 'Choose an answer.',
            choices: const [
              CpChoice('s', 'S'),
              CpChoice('m', 'M'),
              CpChoice('l', 'L'),
            ],
            selected: const {},
            onChanged: (_) {},
          ),
          CpSegmented<String>(
            semanticLabel: 'Adult or child',
            choices: const [
              CpChoice('adult', 'Adult'),
              CpChoice('child', 'Child'),
            ],
            selected: 'adult',
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class _SheetsAndDialogs extends StatelessWidget {
  const _SheetsAndDialogs();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        // A sheet as it sits over the page, shown in place.
        DecoratedBox(
          decoration: BoxDecoration(
            color: cp.colors.surface,
            borderRadius: cp.radii.lg,
            border: Border.all(
              color: cp.colors.border,
              width: cp.sizes.hairline,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: cp.space.lg),
            child: const CpSheet(
              title: 'Choose a group',
              child: CpRowGroup(
                children: [
                  CpListRow(title: 'Mehta', subtitle: '3 people'),
                  CpListRow(title: 'Shah', subtitle: '4 people'),
                ],
              ),
            ),
          ),
        ),
        const CpDialog(
          title: 'Remove Asha Singh?',
          message:
              'They will no longer be counted for this event. This cannot be undone.',
          actions: [
            CpButton.text(label: 'Cancel', onPressed: _noop),
            CpButton.destructive(label: 'Remove', onPressed: _noop),
          ],
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    // Without a photo; a photo shows in its place, cropped to fill.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        const CpCoverBanner(
          icon: CpIcons.templateGroups,
          label: 'Convention',
          semanticLabel: 'Cover photo',
        ),
        Row(
          spacing: cp.space.sm,
          children: const [
            CpCoverThumb(icon: CpIcons.templateGroups),
            CpCoverThumb(icon: CpIcons.templateCelebration),
            CpCoverThumb(icon: CpIcons.templateHeart),
          ],
        ),
      ],
    );
  }
}
