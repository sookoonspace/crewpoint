import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.user,
    this.onSignOut,
    this.onDeleteAccount,
    this.onOpenPrivacy,
  });

  final AppUser? user;
  final VoidCallback? onSignOut;
  final VoidCallback? onDeleteAccount;
  final VoidCallback? onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
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
            onTap: onOpenPrivacy,
          ),
          _ProfileTile(icon: Icons.logout, label: 'Sign Out', onTap: onSignOut),
          _ProfileTile(
            icon: Icons.delete_forever,
            label: 'Delete Account',
            textColor: AppColors.terracotta,
            onTap: onDeleteAccount,
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
