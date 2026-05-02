import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/network_image_with_placeholder.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:crewpoint_app/app/features/profile/presentation/widgets/sign_out_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is Authenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeroCard(user: user)),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: Breakpoints.screenHorizontalPadding(context),
            ),
            sliver: SliverConstrainedCrossAxis(
              maxExtent: 720,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(
                    key: Key('profile.body.clamped'),
                    height: AppSpacing.xl,
                  ),

                  // Settings
                  const _SectionHeader(label: 'SETTINGS'),
                  const SizedBox(height: AppSpacing.sm),
                  _SectionCard(
                    children: [
                      _SettingsTile(
                        key: const Key('profile.privacyDashboard.tile'),
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Dashboard',
                        onTap: () => context.push(AppRoutes.privacyDashboard),
                      ),
                      const Divider(height: 1, indent: 56),
                      _SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Payment
                  const _SectionHeader(label: 'PAYMENT'),
                  const SizedBox(height: AppSpacing.sm),
                  _PaymentCard(user: user),

                  const SizedBox(height: AppSpacing.xl),

                  // Account
                  const _SectionHeader(label: 'ACCOUNT'),
                  const SizedBox(height: AppSpacing.sm),
                  _SectionCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        label: 'Sign Out',
                        onTap: () => SignOutSheet.show(
                          context: context,
                          onSignOut: () =>
                              ref.read(authProvider.notifier).signOut(),
                        ),
                      ),
                    ],
                  ),

                  // Danger zone
                  const SizedBox(height: AppSpacing.xxxl),
                  _DangerCard(
                    onTap: () => DeleteAccountDialog.show(
                      context: context,
                      onDeleted: () {
                        ref
                            .read(onboardingProvider.notifier)
                            .completeOnboarding();
                        if (context.mounted) {
                          context.go(AppRoutes.auth);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                  const _AppVersion(),
                  const SizedBox(height: AppSpacing.xl),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient hero with soft avatar glow.
class _HeroCard extends StatelessWidget {
  const _HeroCard({this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: .topCenter,
          end: .bottomCenter,
          colors: [AppColors.charcoal, AppColors.charcoalDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppColors.offWhite),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Avatar with soft sage glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sage.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: NetworkImageWithPlaceholder.avatar(
                  imageUrl: user?.photoUrl,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Name
              Text(
                user?.displayName ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.offWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Email
              Text(
                user?.email ?? '',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.sageLight),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Edit Profile — filled sage pill
              ElevatedButton(
                onPressed: () => context.push('/profile/edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  foregroundColor: AppColors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.darkGrey,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(
          color: AppColors.lightGrey.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: Column(mainAxisSize: .min, children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.darkGrey),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
      onTap: onTap,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
    );
  }
}

/// Shows payment method + handle, or "Add payment method" prompt.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({this.user});

  final AppUser? user;

  IconData _methodIcon(String? method) => switch (method) {
    'venmo' => Icons.payment,
    'zelle' => Icons.account_balance,
    'cashapp' => Icons.attach_money,
    'paypal' => Icons.paypal_outlined,
    'cash' => Icons.money,
    _ => Icons.payment_outlined,
  };

  String _methodLabel(String? method) => switch (method) {
    'venmo' => 'Venmo',
    'zelle' => 'Zelle',
    'cashapp' => 'Cash App',
    'paypal' => 'PayPal',
    'cash' => 'Cash',
    'other' => 'Other',
    _ => 'Payment',
  };

  @override
  Widget build(BuildContext context) {
    final hasPayment =
        user?.paymentMethod != null && user!.paymentMethod!.isNotEmpty;

    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(
          color: AppColors.lightGrey.withValues(alpha: 0.7),
          width: 0.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          hasPayment
              ? _methodIcon(user?.paymentMethod)
              : Icons.add_circle_outline,
          color: hasPayment ? AppColors.darkGrey : AppColors.sage,
        ),
        title: hasPayment
            ? Text(
                '${_methodLabel(user?.paymentMethod)}: ${user?.paymentHandle ?? ''}',
              )
            : const Text(
                'Add payment method',
                style: TextStyle(color: AppColors.sage),
              ),
        subtitle: hasPayment
            ? null
            : Text(
                'Let your crew know how to pay you',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
              ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
        onTap: () => context.push('/profile/edit'),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(color: AppColors.terracotta.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: AppColors.terracotta),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppColors.terracotta),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.terracottaLight,
        ),
        onTap: onTap,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }
}

class _AppVersion extends StatelessWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '...';
        final buildNumber = snapshot.data?.buildNumber ?? '';
        return Center(
          child: Text(
            'CrewPoint v$version${buildNumber.isNotEmpty ? ' ($buildNumber)' : ''}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
          ),
        );
      },
    );
  }
}
