import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';

/// Bottom-sheet chooser for `ThemeMode`. Three options: System / Light / Dark.
///
/// All colors resolve from `Theme.of(context).colorScheme` so the sheet
/// renders correctly under either theme. Modeled structurally on
/// `SignOutSheet` but does NOT reuse its hardcoded color references.
class ThemeSwitcherSheet extends ConsumerWidget {
  const ThemeSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (_) => const ThemeSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final s = context.strings.profile;
    final colors = Theme.of(context).colorScheme;

    void onChanged(ThemeMode? mode) {
      if (mode == null) return;
      ref.read(themeModeProvider.notifier).set(mode);
      Navigator.of(context).pop();
    }

    return Padding(
      key: const Key('profile.theme.sheet'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        MediaQuery.viewPaddingOf(context).bottom + AppSpacing.lg,
      ),
      child: RadioGroup<ThemeMode>(
        groupValue: current,
        onChanged: onChanged,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            RadioListTile<ThemeMode>(
              key: const Key('profile.theme.sheet.option.system'),
              value: ThemeMode.system,
              title: Text(s.themeModeSystem),
              subtitle: Text(s.themeModeSystemSubtitle),
            ),
            RadioListTile<ThemeMode>(
              key: const Key('profile.theme.sheet.option.light'),
              value: ThemeMode.light,
              title: Text(s.themeModeLight),
            ),
            RadioListTile<ThemeMode>(
              key: const Key('profile.theme.sheet.option.dark'),
              value: ThemeMode.dark,
              title: Text(s.themeModeDark),
            ),
          ],
        ),
      ),
    );
  }
}
