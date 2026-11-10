import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';
import 'package:crewpoint_app/app/features/participants/application/account_linker.dart';

/// Keeps [accountLinkerProvider] running while someone is signed in, and
/// says when signing in linked them to a registration (Req 46). Draws
/// nothing.
class AccountLinkListener extends ConsumerWidget {
  const AccountLinkListener({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LinkResult?>(accountLinkerProvider, (_, next) {
      final linked = next?.linked.length ?? 0;
      if (linked == 0) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          key: const Key('links.linkedToast'),
          content: Text(context.strings.links.linkedToast(linked)),
        ),
      );
    });
    return const SizedBox.shrink();
  }
}
