import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';

class SocialAuthButtons extends ConsumerWidget {
  const SocialAuthButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appleAsset = isDark
        ? 'assets/images/auth/Apple_logo_white.svg'
        : 'assets/images/auth/Apple_logo_black.svg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.cp.space.md,
      children: [
        _SocialButton(
          buttonKey: const Key('auth.button.google'),
          iconKey: const Key('auth.button.google.icon'),
          label: context.strings.auth.continueWithGoogle,
          svgAsset: 'assets/images/auth/google_logo.svg',
          fallbackIcon: CpIcons.authGoogle,
          onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
        ),
        _SocialButton(
          buttonKey: const Key('auth.button.apple'),
          iconKey: const Key('auth.button.apple.icon'),
          label: context.strings.auth.continueWithApple,
          svgAsset: appleAsset,
          fallbackIcon: CpIcons.authApple,
          onPressed: () => ref.read(authProvider.notifier).signInWithApple(),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.buttonKey,
    required this.iconKey,
    required this.label,
    required this.svgAsset,
    required this.fallbackIcon,
    required this.onPressed,
  });

  final Key buttonKey;
  final Key iconKey;
  final String label;
  final String svgAsset;
  final IconData fallbackIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final side = context.cp.sizes.iconMd;
    return CpButton.secondary(
      key: buttonKey,
      label: label,
      expand: true,
      leading: SvgPicture.asset(
        svgAsset,
        key: iconKey,
        width: side,
        height: side,
        placeholderBuilder: (_) {
          developer.log(
            'Brand SVG failed to load: $svgAsset',
            name: 'auth.brand',
          );
          return Icon(fallbackIcon, size: side);
        },
      ),
      onPressed: onPressed,
    );
  }
}
