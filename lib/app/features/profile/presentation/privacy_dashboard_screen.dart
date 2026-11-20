import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/profile/presentation/markdown_render_screen.dart';

/// What the app keeps about you and why, what it never keeps, the
/// services it relies on, and the legal documents.
class PrivacyDashboardScreen extends StatelessWidget {
  const PrivacyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.privacy;
    final navigator = Navigator.of(context);

    Icon icon(IconData data, {Color? color}) =>
        Icon(data, size: cp.sizes.iconMd, color: color ?? cp.colors.textMuted);

    void openDocument(String title, String asset, String path) =>
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MarkdownRenderScreen(
              title: title,
              assetPath: asset,
              hostedUrl: '${AppFlavor.current.legalBaseUrl}/$path',
            ),
          ),
        );

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: s.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
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
              key: const Key('privacyDashboard.body.clamped'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                CpSectionHeader(title: s.collectedHeading),
                CpCard(
                  child: CpRowGroup(
                    children: [
                      for (final item in s.collected)
                        CpListRow(
                          leading: item.required
                              ? icon(
                                  CpIcons.statusDone,
                                  color: cp.colors.accent,
                                )
                              : icon(CpIcons.circleOutlined),
                          title: item.field,
                          subtitle: item.purpose,
                          trailing: CpTag(
                            label: item.required ? s.required : s.optional,
                            tone: item.required
                                ? CpTagTone.accent
                                : CpTagTone.quiet,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(cp.space.lg),
                  decoration: BoxDecoration(
                    color: cp.colors.accentSoft,
                    borderRadius: cp.radii.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: cp.space.md,
                    children: [
                      icon(CpIcons.statusInfo, color: cp.colors.accent),
                      Expanded(
                        child: Text(
                          s.paymentNote,
                          style: cp.type.bodyMedium.copyWith(
                            color: cp.colors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CpSectionHeader(title: s.notCollectedHeading),
                CpCard(
                  child: CpRowGroup(
                    children: [
                      for (final item in s.notCollected)
                        CpListRow(leading: icon(CpIcons.blocked), title: item),
                    ],
                  ),
                ),
                CpSectionHeader(title: s.servicesHeading),
                CpCard(
                  child: CpRowGroup(
                    children: [
                      for (final service in s.services)
                        CpListRow(
                          leading: icon(CpIcons.extension),
                          title: service.name,
                          subtitle: service.purpose,
                        ),
                    ],
                  ),
                ),
                CpSectionHeader(title: s.legalHeading),
                CpCard(
                  child: CpRowGroup(
                    children: [
                      CpListRow(
                        key: const Key('privacyDashboard.legal.privacy'),
                        leading: icon(CpIcons.privacyPolicy),
                        title: s.privacyPolicy,
                        onTap: () => openDocument(
                          s.privacyPolicy,
                          AppAssets.legalPrivacyPolicy,
                          'privacy',
                        ),
                      ),
                      CpListRow(
                        key: const Key('privacyDashboard.legal.terms'),
                        leading: icon(CpIcons.terms),
                        title: s.terms,
                        onTap: () => openDocument(
                          s.terms,
                          AppAssets.legalTermsOfService,
                          'terms',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
