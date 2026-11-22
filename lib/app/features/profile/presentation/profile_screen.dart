import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/profile/application/current_user_doc_provider.dart';
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';
import 'package:crewpoint_app/app/core/widgets/language_switch.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/profile_photo.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/sign_out_sheet.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/theme_switcher_sheet.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';

/// What the user owes, one amount per currency, because they cannot be added.
String formatAmountsYouOwe(LedgerSummary ledger) {
  final owed = [
    for (final entry in ledger.totalsByCurrency.entries)
      if (entry.value.youOwe > 0)
        NumberFormat.simpleCurrency(
          name: entry.key,
          decimalDigits: 0,
        ).format(entry.value.youOwe),
  ];
  return owed.isEmpty ? r'$0' : owed.join(' + ');
}

/// The signed-in person's profile tab (Spec #186): who they are, their
/// figures at a glance, settings, payment, then signing out and deleting
/// the account.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final asyncDoc = ref.watch(currentUserDocProvider);
    // Prefer the Firestore-backed user (carries derived displayName +
    // payment fields). Fall back to auth-only AppUser while the first
    // snapshot is in flight or when unauthenticated.
    final user =
        asyncDoc.value ?? (authState is Authenticated ? authState.user : null);

    final uid = ref.watch(currentUserIdProvider);
    final eventsAsync = ref.watch(dashboardEventsProvider);
    final tasksAsync = uid == null
        ? const AsyncValue<List<MyAssignedTaskRow>>.loading()
        : ref.watch(myAssignedTasksProvider(uid));
    final ledgerAsync = uid == null
        ? const AsyncValue<LedgerSummary>.loading()
        : ref.watch(globalBalanceLedgerProvider(uid));

    // A dash while a figure is still loading.
    const loading = '—';
    final events = eventsAsync.value?.length.toString() ?? loading;
    final tasks = tasksAsync.value?.length.toString() ?? loading;
    final owed = ledgerAsync.hasValue
        ? formatAmountsYouOwe(ledgerAsync.requireValue)
        : loading;

    final cp = context.cp;
    final s = context.strings.profile;

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(title: s.heroTitle),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: Column(
              key: const Key('profile.body.clamped'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                _PersonCard(user: user),
                CpStatGrid(
                  key: const Key('profile.statTriplet'),
                  children: [
                    CpStatCard(
                      icon: CpIcons.event,
                      label: s.statsEvents,
                      value: events,
                    ),
                    CpStatCard(
                      icon: CpIcons.tasks,
                      label: s.statsTasks,
                      value: tasks,
                    ),
                    CpStatCard(
                      icon: CpIcons.budget,
                      label: s.statsOwed,
                      value: owed,
                    ),
                  ],
                ),
                CpSectionHeader(title: s.settingsSection),
                CpCard(
                  child: CpRowGroup(
                    children: [
                      CpListRow(
                        key: const Key('profile.privacyDashboard.tile'),
                        leading: const _RowIcon(CpIcons.privacy),
                        title: s.privacyDashboard,
                        onTap: () => context.push(AppRoutes.privacyDashboard),
                      ),
                      const _ThemeRow(),
                      const _LanguageRow(),
                      CpListRow(
                        key: const Key('profile.notifications.tile'),
                        leading: const _RowIcon(CpIcons.notifications),
                        title: s.notifications,
                        onTap: () =>
                            context.push(AppRoutes.notificationSettings),
                      ),
                      // Dev flavor only: hidden on stg and prod builds.
                      if (AppFlavor.current == AppFlavor.dev)
                        CpListRow(
                          key: const Key('profile.devTools.tile'),
                          leading: const _RowIcon(CpIcons.devTools),
                          title: s.devTools,
                          onTap: () => context.push(AppRoutes.devTools),
                        ),
                    ],
                  ),
                ),
                CpSectionHeader(title: s.paymentSection),
                _PaymentCard(user: user),
                SizedBox(height: cp.space.sm),
                CpButton.secondary(
                  key: const Key('profile.signOut.button'),
                  label: s.signOut,
                  icon: CpIcons.actionLogout,
                  expand: true,
                  onPressed: () => SignOutSheet.show(
                    context: context,
                    onSignOut: () => ref.read(authProvider.notifier).signOut(),
                  ),
                ),
                // The dialog owns deletion end to end; the router's redirect
                // moves to sign-in once the account is gone.
                CpButton.destructive(
                  key: const Key('profile.deleteAccount.button'),
                  label: s.deleteAccount,
                  icon: CpIcons.actionDeletePermanent,
                  expand: true,
                  onPressed: () => DeleteAccountDialog.show(context: context),
                ),
                const _AppVersion(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row's icon.
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Icon(icon, size: cp.sizes.iconMd, color: cp.colors.textMuted);
  }
}

/// The person: photo or initials, name, email and Edit profile.
class _PersonCard extends StatelessWidget {
  const _PersonCard({this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.profile;
    final name = user?.displayName ?? s.heroUserFallback;
    final email = user?.email ?? '';
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.lg,
        children: [
          Row(
            spacing: cp.space.lg,
            children: [
              ProfilePhoto(url: user?.photoUrl, name: name),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.xs,
                  children: [
                    Text(
                      name,
                      style: cp.type.titleLarge.copyWith(color: cp.colors.text),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: cp.type.bodyMedium.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          CpButton.secondary(
            key: const Key('profile.edit.open'),
            label: s.editProfileCta,
            icon: CpIcons.actionEdit,
            expand: true,
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
    );
  }
}

/// The payment method and handle, or a prompt to add one.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({this.user});

  final AppUser? user;

  IconData _methodIcon(String? method) => switch (method) {
    'venmo' => CpIcons.paymentVenmo,
    'zelle' => CpIcons.paymentZelle,
    'cashapp' => CpIcons.paymentCashApp,
    'paypal' => CpIcons.paymentPayPal,
    'cash' => CpIcons.paymentCash,
    _ => CpIcons.paymentGeneric,
  };

  String _methodLabel(ProfileStrings s, String? method) => switch (method) {
    'venmo' => s.paymentMethodVenmo,
    'zelle' => s.paymentMethodZelle,
    'cashapp' => s.paymentMethodCashApp,
    'paypal' => s.paymentMethodPayPal,
    'cash' => s.paymentMethodCash,
    'other' => s.paymentMethodOther,
    _ => s.paymentMethodGeneric,
  };

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final method = user?.paymentMethod;
    final hasPayment = method != null && method.isNotEmpty;
    final s = context.strings.profile;
    return CpCard(
      child: CpListRow(
        key: const Key('profile.payment.tile'),
        leading: hasPayment
            ? _RowIcon(_methodIcon(method))
            : Icon(
                CpIcons.actionAddCircle,
                size: cp.sizes.iconMd,
                color: cp.colors.accent,
              ),
        title: hasPayment
            ? '${_methodLabel(s, method)}: ${user?.paymentHandle ?? ''}'
            : s.addPaymentMethod,
        subtitle: hasPayment ? null : s.addPaymentMethodSubtitle,
        onTap: () => context.push('/profile/edit'),
      ),
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final mode = ref.watch(themeModeProvider);
    final s = context.strings.profile;
    final label = switch (mode) {
      ThemeMode.system => s.themeModeSystem,
      ThemeMode.light => s.themeModeLight,
      ThemeMode.dark => s.themeModeDark,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        // With large text the choice goes under the title, so neither wraps
        // mid-word.
        if (constraints.maxWidth / scale < 260) {
          return CpListRow(
            key: const Key('profile.theme.row'),
            leading: const _RowIcon(CpIcons.theme),
            title: s.themeRowTitle,
            subtitle: label,
            onTap: () => ThemeSwitcherSheet.show(context),
          );
        }
        return CpListRow(
          key: const Key('profile.theme.row'),
          leading: const _RowIcon(CpIcons.theme),
          title: s.themeRowTitle,
          onTap: () => ThemeSwitcherSheet.show(context),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: cp.space.xs,
            children: [
              Text(
                label,
                key: const Key('profile.theme.row.trailing'),
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              ),
              Icon(
                CpIcons.chevronRight,
                size: cp.sizes.iconMd,
                color: cp.colors.textMuted,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// English or ગુજરાતી (Spec #233 Req 56), the choice under its title so it
/// fits at 320 px with large text.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.language;
    return Padding(
      key: const Key('profile.language.row'),
      padding: EdgeInsets.symmetric(
        horizontal: cp.space.lg,
        vertical: cp.space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.sm,
        children: [
          Row(
            spacing: cp.space.md,
            children: [
              const _RowIcon(CpIcons.language),
              Expanded(child: Text(s.title, style: cp.type.bodyLarge)),
            ],
          ),
          const LanguageSwitch(keyPrefix: 'profile.language'),
        ],
      ),
    );
  }
}

class _AppVersion extends StatelessWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '...';
        final buildNumber = snapshot.data?.buildNumber ?? '';
        return Text(
          context.strings.profile.appVersionLabel(
            version: version,
            build: buildNumber,
          ),
          textAlign: TextAlign.center,
          style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
        );
      },
    );
  }
}
