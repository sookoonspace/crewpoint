import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/version/app_version_check.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a full-screen upgrade message in place of the app when it is below
/// the minimum version in `config/app` (Req 34a). Sits in
/// `MaterialApp.router`'s `builder`, so the router is never rebuilt. While
/// the check runs, or if it fails, the app shows as normal.
class AppUpdateGate extends ConsumerWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirement = ref.watch(appUpdateRequirementProvider).value;
    if (requirement == null) return child;
    return AppUpdateScreen(requirement: requirement);
  }
}

class AppUpdateScreen extends ConsumerWidget {
  const AppUpdateScreen({super.key, required this.requirement});

  final AppUpdateRequirement requirement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.update;
    final isWeb = ref.watch(appPlatformProvider) == AppPlatform.web;
    final storeUrl = requirement.storeUrl;

    final Widget action;
    if (isWeb) {
      action = CpButton(
        key: const Key('app.update.reload'),
        label: strings.reload,
        icon: CpIcons.actionRetry,
        expand: true,
        onPressed: () => ref.read(pageReloaderProvider).reload(),
      );
    } else if (storeUrl != null) {
      action = CpButton(
        key: const Key('app.update.store'),
        label: strings.openStore,
        icon: CpIcons.actionOpenInNew,
        expand: true,
        onPressed: () => ref.read(urlLauncherProvider).launch(storeUrl),
      );
    } else {
      action = Text(
        strings.noStoreLink,
        textAlign: TextAlign.center,
        style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
      );
    }

    return Scaffold(
      key: const Key('app.update.screen'),
      backgroundColor: cp.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(cp.space.xl),
            child: ContentMaxWidth(
              maxWidth: cp.sizes.signInColumn,
              child: CpCard(
                padding: EdgeInsets.all(cp.space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: cp.space.lg,
                  children: [
                    Icon(
                      CpIcons.appUpdate,
                      size: cp.sizes.iconHero,
                      color: cp.colors.accent,
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        strings.title,
                        textAlign: TextAlign.center,
                        style: cp.type.headlineSmall.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                    ),
                    Text(
                      strings.body,
                      textAlign: TextAlign.center,
                      style: cp.type.bodyLarge.copyWith(
                        color: cp.colors.textMuted,
                      ),
                    ),
                    action,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
