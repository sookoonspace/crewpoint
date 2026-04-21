import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';

import 'package:crewpoint_app/app/features/profile/presentation/widgets/delete_account_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is Authenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const _Avatar(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            user?.displayName ?? 'User',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          Text(
            user?.email ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGrey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _ProfileTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Dashboard',
            onTap: () {
              // Navigate to privacy dashboard
            },
          ),
          _ProfileTile(
            icon: Icons.logout,
            label: 'Sign Out',
            onTap: () => ref.read(authProvider.notifier).signOut(),
          ),
          _ProfileTile(
            icon: Icons.delete_forever,
            label: 'Delete Account',
            textColor: AppColors.terracotta,
            onTap: () => DeleteAccountDialog.show(
              context: context,
              onDeleted: () {
                // Reset onboarding state and navigate out
                ref.read(onboardingProvider.notifier).completeOnboarding();
                if (context.mounted) {
                  context.go(AppRoutes.auth);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.sageLight,
        child: Icon(Icons.person, size: 48, color: AppColors.white),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    this.textColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(label, style: TextStyle(color: textColor)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
