import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// While a mirror reads from the device's cache, says so and when it last
/// heard from the server (Req 74). Shows nothing online, and nothing on web,
/// which has no mirror.
class LastUpdatedNote extends ConsumerWidget {
  const LastUpdatedNote({super.key, required this.mirrorKey});

  /// Such as `tasks/{eventId}`.
  final String mirrorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();
    final sync = ref.watch(mirrorSyncProvider(mirrorKey)).value;
    if (sync == null || !sync.fromCache) return const SizedBox.shrink();
    final cp = context.cp;
    final at = sync.syncedAt;
    final text = context.strings.agenda.offline(
      at == null ? null : DateFormat.MMMd().add_jm().format(at.toLocal()),
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('offline.note'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: cp.colors.fill,
          border: Border(
            bottom: BorderSide(
              color: cp.colors.border,
              width: cp.sizes.hairline,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: cp.space.lg,
          vertical: cp.space.sm,
        ),
        child: Row(
          spacing: cp.space.sm,
          children: [
            Icon(
              CpIcons.cloudOff,
              size: cp.sizes.iconSm,
              color: cp.colors.textMuted,
            ),
            Expanded(
              child: Text(
                text,
                style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
