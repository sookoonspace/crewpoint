import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Asks before signing out. The caller signs out through [onSignOut].
class SignOutSheet extends StatelessWidget {
  const SignOutSheet({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onSignOut,
  }) {
    return showCpSheet<void>(
      context: context,
      title: context.strings.profile.signOutTitle,
      builder: (_) => SignOutSheet(onSignOut: onSignOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.profile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.lg,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: cp.space.md,
          children: [
            Icon(
              CpIcons.wavingHand,
              size: cp.sizes.iconMd,
              color: cp.colors.textMuted,
            ),
            Expanded(
              child: Text(
                s.signOutBody,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              ),
            ),
          ],
        ),
        CpButton(
          key: const Key('profile.signOut.confirm'),
          label: s.signOut,
          icon: CpIcons.actionLogout,
          expand: true,
          onPressed: () {
            Navigator.of(context).pop();
            onSignOut?.call();
          },
        ),
        CpButton.secondary(
          key: const Key('profile.signOut.cancel'),
          label: s.cancel,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
