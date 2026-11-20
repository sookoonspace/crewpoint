import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';

/// Chooses the app's appearance: the device's, light or dark. Choosing one
/// applies it and closes the sheet.
class ThemeSwitcherSheet extends ConsumerWidget {
  const ThemeSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCpSheet<void>(
      context: context,
      title: context.strings.profile.themeRowTitle,
      builder: (_) => const ThemeSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final current = ref.watch(themeModeProvider);
    final s = context.strings.profile;

    Widget option(ThemeMode mode, String label, {String? help}) {
      final chosen = mode == current;
      return CpListRow(
        key: Key('profile.theme.sheet.option.${mode.name}'),
        title: label,
        subtitle: help,
        selected: chosen,
        trailing: chosen
            ? Icon(
                CpIcons.statusDone,
                size: cp.sizes.iconMd,
                color: cp.colors.accent,
              )
            : const SizedBox.shrink(),
        onTap: () {
          ref.read(themeModeProvider.notifier).set(mode);
          Navigator.of(context).pop();
        },
      );
    }

    return CpCard(
      key: const Key('profile.theme.sheet'),
      child: CpRowGroup(
        children: [
          option(
            ThemeMode.system,
            s.themeModeSystem,
            help: s.themeModeSystemSubtitle,
          ),
          option(ThemeMode.light, s.themeModeLight),
          option(ThemeMode.dark, s.themeModeDark),
        ],
      ),
    );
  }
}
