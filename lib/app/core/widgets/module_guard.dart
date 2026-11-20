import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Shows [child] only while [module] is on, so a saved link or a notification
/// cannot open a part of the event that has been turned off.
class ModuleGuard extends StatelessWidget {
  const ModuleGuard({
    super.key,
    required this.event,
    required this.module,
    required this.child,
  });

  final EventModel event;
  final String module;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (event.isModuleOn(module)) return child;
    final strings = context.strings.dashboard;
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: context.cp.colors.background,
      appBar: CpTopBar(
        title: event.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
      body: SingleChildScrollView(
        child: CpEmptyState(
          key: const Key('events.module.off'),
          icon: CpIcons.hidden,
          title: strings.moduleOff,
          actionLabel: strings.settingsBack,
          actionKey: const Key('events.module.back'),
          onAction: () => context.go('/dashboard/event/${event.id}'),
        ),
      ),
    );
  }
}
