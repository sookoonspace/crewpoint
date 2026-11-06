import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/version/app_version_check.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
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
    final strings = context.strings.update;
    final theme = Theme.of(context);
    final isWeb = ref.watch(appPlatformProvider) == AppPlatform.web;
    final storeUrl = requirement.storeUrl;

    final Widget action;
    if (isWeb) {
      action = PrimaryButton(
        key: const Key('app.update.reload'),
        label: strings.reload,
        onPressed: () => ref.read(pageReloaderProvider).reload(),
      );
    } else if (storeUrl != null) {
      action = PrimaryButton(
        key: const Key('app.update.store'),
        label: strings.openStore,
        onPressed: () => ref.read(urlLauncherProvider).launch(storeUrl),
      );
    } else {
      action = Text(
        strings.noStoreLink,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      );
    }

    return Scaffold(
      key: const Key('app.update.screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Breakpoints.screenHorizontalPadding(context),
              vertical: AppSpacing.xl,
            ),
            child: ContentMaxWidth(
              maxWidth: Breakpoints.compactMax,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.appUpdate,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      strings.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    strings.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
