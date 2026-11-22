import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/i18n/app_language.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// English or ગુજરાતી, side by side (Spec #233 Req 56). Shown before sign-in
/// and in Profile; the event page adds it in Stage 2A's later work. Each
/// option is written in its own language. Keys: `<keyPrefix>.en`, `.gu`.
class LanguageSwitch extends ConsumerWidget {
  const LanguageSwitch({super.key, required this.keyPrefix});

  /// For tests, such as `auth.language`.
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.language;
    return CpSegmented<AppLanguage>(
      semanticLabel: s.title,
      selected: ref.watch(appLanguageProvider),
      onChanged: ref.read(appLanguageProvider.notifier).set,
      choices: [
        CpChoice(AppLanguage.en, s.english, key: Key('$keyPrefix.en')),
        CpChoice(AppLanguage.gu, s.gujarati, key: Key('$keyPrefix.gu')),
      ],
    );
  }
}
