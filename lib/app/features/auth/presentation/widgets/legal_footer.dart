import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Auth-gate legal footer.
///
/// "By continuing, you agree to our [Terms] and [Privacy Policy]." with
/// each link tappable. Links resolve via `AppFlavor.current.legalBaseUrl`
/// so production builds open `crewpoint.sookoon.space/...`, never
/// `*.web.app`.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key, this.urlLauncher = launchUrl});

  /// Test seam — defaults to the real `url_launcher.launchUrl`.
  final Future<bool> Function(Uri, {LaunchMode mode}) urlLauncher;

  static const termsKey = Key('auth.legal.termsLink');
  static const privacyKey = Key('auth.legal.privacyLink');

  Future<void> _open(BuildContext context, String suffix) async {
    final url = '${AppFlavor.current.legalBaseUrl}$suffix';
    final uri = Uri.parse(url);
    try {
      final ok = await urlLauncher(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    } catch (e, st) {
      log(
        'Failed to launch legal URL $url',
        error: e,
        stackTrace: st,
        name: 'auth.legal',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.strings.auth;
    final base = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.darkGrey);
    final linkStyle = base?.copyWith(
      color: AppColors.sageDark,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: auth.legalFooterPrefix),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                key: termsKey,
                onTap: () => _open(context, '/terms'),
                child: Text(auth.legalFooterTermsLink, style: linkStyle),
              ),
            ),
            TextSpan(text: auth.legalFooterAnd),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                key: privacyKey,
                onTap: () => _open(context, '/privacy'),
                child: Text(auth.legalFooterPrivacyLink, style: linkStyle),
              ),
            ),
            TextSpan(text: auth.legalFooterSuffix),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
