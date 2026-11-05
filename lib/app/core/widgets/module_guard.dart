import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.lg,
            children: [
              Text(
                strings.moduleOff,
                key: const Key('events.module.off'),
                textAlign: TextAlign.center,
              ),
              OutlinedButton(
                key: const Key('events.module.back'),
                onPressed: () => context.go('/dashboard/event/${event.id}'),
                child: Text(strings.settingsBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
