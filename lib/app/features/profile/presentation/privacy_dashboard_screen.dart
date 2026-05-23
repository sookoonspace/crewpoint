import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/profile/presentation/markdown_render_screen.dart';

/// Privacy-first dashboard showing what data we collect and why.
class PrivacyDashboardScreen extends StatelessWidget {
  const PrivacyDashboardScreen({super.key});

  static const _dataCollected = [
    ('Display Name', 'How you appear to crew members', true),
    ('Email', 'Contact for settlements, account recovery', true),
    ('Profile Photo', 'Avatar in events, chat, expenses', false),
    ('Payment Method', 'Show crew how to pay you (Venmo, Zelle, etc.)', false),
    ('Payment Handle', 'Your @username or phone for chosen method', false),
    ('Currency', 'Display formatting preference', false),
    ('Usage Analytics', 'Anonymous app improvement data', false),
  ];

  static const _notCollected = [
    'Phone number (unless you add it as payment handle)',
    'Physical address, birthday, or demographics',
    'Device identifiers or advertising IDs',
    'Contacts or social graph',
    'Location data',
    'Browsing or usage history (unless opted in)',
  ];

  static const _dependencies = [
    ('Firebase Auth', 'Authentication services'),
    ('Cloud Firestore', 'Real-time database'),
    ('Firebase Storage', 'Profile photo storage'),
    ('Cloud Functions', 'Account deletion (server-side)'),
    ('Google Sign-In', 'Social authentication'),
    ('Sign in with Apple', 'Social authentication'),
    ('Drift (SQLite)', 'Local offline database'),
    ('Flutter Secure Storage', 'Encrypted token storage'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Dashboard'),
        elevation: 0,
      ),
      body: ContentMaxWidth(
        key: const Key('privacyDashboard.body.clamped'),
        maxWidth: 720,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: Breakpoints.screenHorizontalPadding(context),
            vertical: AppSpacing.xl,
          ),
          children: [
            // Data We Collect
            const _SectionLabel(label: 'DATA WE COLLECT'),
            const SizedBox(height: AppSpacing.sm),
            _SectionCard(
              children: [
                for (var i = 0; i < _dataCollected.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  _DataRow(
                    field: _dataCollected[i].$1,
                    purpose: _dataCollected[i].$2,
                    isRequired: _dataCollected[i].$3,
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Payment Info Note
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                crossAxisAlignment: .start,
                spacing: AppSpacing.md,
                children: [
                  const Icon(
                    AppIcons.statusInfo,
                    color: AppColors.sage,
                    size: 20,
                  ),
                  Expanded(
                    child: Text(
                      'Your payment details (Venmo handle, etc.) are visible to other CrewPoint users to facilitate settlements.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.sageDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // What We Don't Collect
            const _SectionLabel(label: 'WHAT WE DO NOT COLLECT'),
            const SizedBox(height: AppSpacing.sm),
            _SectionCard(
              children: [
                for (var i = 0; i < _notCollected.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      AppIcons.blocked,
                      color: AppColors.mediumGrey,
                      size: 20,
                    ),
                    title: Text(
                      _notCollected[i],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    dense: true,
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Third-Party Services
            const _SectionLabel(label: 'THIRD-PARTY SERVICES'),
            const SizedBox(height: AppSpacing.sm),
            _SectionCard(
              children: [
                for (var i = 0; i < _dependencies.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      AppIcons.extension,
                      color: AppColors.darkGrey,
                      size: 20,
                    ),
                    title: Text(_dependencies[i].$1),
                    subtitle: Text(
                      _dependencies[i].$2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGrey,
                      ),
                    ),
                    dense: true,
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Legal Documents
            const _SectionLabel(label: 'LEGAL DOCUMENTS'),
            const SizedBox(height: AppSpacing.sm),
            _SectionCard(
              children: [
                ListTile(
                  key: const Key('privacyDashboard.legal.privacy'),
                  leading: const Icon(
                    AppIcons.privacyPolicy,
                    color: AppColors.darkGrey,
                  ),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(
                    AppIcons.chevronRight,
                    color: AppColors.mediumGrey,
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => MarkdownRenderScreen(
                        title: 'Privacy Policy',
                        assetPath: AppAssets.legalPrivacyPolicy,
                        hostedUrl: '${AppFlavor.current.legalBaseUrl}/privacy',
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  key: const Key('privacyDashboard.legal.terms'),
                  leading: const Icon(
                    AppIcons.terms,
                    color: AppColors.darkGrey,
                  ),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(
                    AppIcons.chevronRight,
                    color: AppColors.mediumGrey,
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => MarkdownRenderScreen(
                        title: 'Terms of Service',
                        assetPath: AppAssets.legalTermsOfService,
                        hostedUrl: '${AppFlavor.current.legalBaseUrl}/terms',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

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

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.field,
    required this.purpose,
    required this.isRequired,
  });

  final String field;
  final String purpose;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isRequired ? AppIcons.statusDone : AppIcons.circleOutlined,
        color: isRequired ? AppColors.sage : AppColors.mediumGrey,
        size: 20,
      ),
      title: Text(field),
      subtitle: Text(purpose, style: Theme.of(context).textTheme.bodySmall),
      trailing: isRequired
          ? Text(
              'Required',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.darkGrey),
            )
          : Text('Optional', style: Theme.of(context).textTheme.labelSmall),
      dense: true,
    );
  }
}
