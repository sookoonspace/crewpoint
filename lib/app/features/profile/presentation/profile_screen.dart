import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
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
          // Hero card (charcoal header)
          SliverToBoxAdapter(child: _HeroCard(user: user)),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.sm),

                // Settings section
                const _SectionHeader(label: 'SETTINGS'),
                const SizedBox(height: AppSpacing.sm),
                _SectionCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Dashboard',
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Account section
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

                // Danger zone — isolated card
                const SizedBox(height: AppSpacing.xxl),
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

                // App version
                const SizedBox(height: AppSpacing.xxl),
                const _AppVersion(),
                const SizedBox(height: AppSpacing.lg),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Charcoal hero card with avatar, name, email, edit button.
class _HeroCard extends StatelessWidget {
  const _HeroCard({this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.xxl),
          bottomRight: Radius.circular(AppRadius.xxl),
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
              // Title bar
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
              const SizedBox(height: AppSpacing.xl),

              // Avatar with sage ring
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sage,
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.charcoalDark,
                  child: user?.photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            user!.photoUrl!,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildProfileAnimation(),
                          ),
                        )
                      : _buildProfileAnimation(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              Text(
                user?.displayName ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.offWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Email
              Text(
                user?.email ?? '',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.sageLight),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Edit Profile button
              OutlinedButton(
                onPressed: () => context.push('/profile/edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.offWhite,
                  side: const BorderSide(color: AppColors.sage),
                  shape: const StadiumBorder(),
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

  Widget _buildProfileAnimation() {
    return Lottie.asset(
      'assets/animations/profile.json',
      width: 64,
      height: 64,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.person, size: 48, color: AppColors.sageLight),
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
      elevation: 1,
      color: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: Column(mainAxisSize: .min, children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.charcoal),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
      onTap: onTap,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
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
