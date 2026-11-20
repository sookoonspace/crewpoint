import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';

/// Per-user, per-event mute picker. Surfaces 4 preset durations
/// (1h / 8h / 1d / "Until I unmute") plus an Unmute CTA when an
/// active mute exists. Persists via `EventMuteRepository.muteEvent`
/// (sealed `mutedUntil` write — see `users/{uid}/eventMutes/{eventId}`).
///
/// Server-side enforcement lives in `functions/src/notifications/suppress.ts`
/// (`shouldSuppress` — under Option B, an active event mute silences
/// every category including `chat_urgent`).
class MuteEventSheet extends ConsumerWidget {
  const MuteEventSheet({super.key, required this.uid, required this.eventId});

  final String uid;
  final String eventId;

  static Future<void> show({
    required BuildContext context,
    required String uid,
    required String eventId,
  }) {
    return showCpSheet<void>(
      context: context,
      builder: (_) => MuteEventSheet(uid: uid, eventId: eventId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.dashboard;
    final asyncMute = ref.watch(
      eventMuteProvider((uid: uid, eventId: eventId)),
    );
    final activeMute = asyncMute.maybeWhen(data: (m) => m, orElse: () => null);
    final isActive =
        activeMute != null && activeMute.isMutedAt(clock.now().toUtc());

    Widget option(
      String key,
      String label,
      IconData icon,
      VoidCallback onTap,
    ) => CpListRow(
      key: Key(key),
      leading: Icon(icon, size: cp.sizes.iconMd, color: cp.colors.accent),
      title: label,
      trailing: const SizedBox.shrink(),
      onTap: onTap,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        Semantics(
          header: true,
          child: Text(
            isActive ? strings.mutedTitle : strings.muteTitle,
            style: cp.type.titleLarge.copyWith(color: cp.colors.text),
          ),
        ),
        Text(
          isActive
              ? strings.mutedUntil(
                  DateFormat.yMMMd().add_jm().format(
                    activeMute.mutedUntil.toLocal(),
                  ),
                )
              : strings.muteHelp,
          style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
        ),
        CpCard(
          child: CpRowGroup(
            children: isActive
                ? [
                    option(
                      'muteSheet.unmute',
                      strings.unmute,
                      CpIcons.actionUnmute,
                      () async {
                        await ref
                            .read(eventMuteRepositoryProvider)
                            .unmuteEvent(uid: uid, eventId: eventId);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ]
                : [
                    option(
                      'muteSheet.duration.1h',
                      strings.muteHour,
                      CpIcons.muteHour,
                      () => _mute(context, ref, const Duration(hours: 1)),
                    ),
                    option(
                      'muteSheet.duration.8h',
                      strings.muteEightHours,
                      CpIcons.muteNight,
                      () => _mute(context, ref, const Duration(hours: 8)),
                    ),
                    option(
                      'muteSheet.duration.1d',
                      strings.muteDay,
                      CpIcons.muteDay,
                      () => _mute(context, ref, const Duration(days: 1)),
                    ),
                    option(
                      'muteSheet.duration.untilUnmute',
                      strings.muteUntilUnmute,
                      CpIcons.actionMute,
                      // 10 years is "forever" for practical purposes; the
                      // server honours the timestamp literally and the user
                      // can always open this sheet again to unmute. Keeps
                      // the schema as a single `mutedUntil` field without a
                      // separate "indefinite" sentinel.
                      () => _mute(context, ref, const Duration(days: 365 * 10)),
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  Future<void> _mute(
    BuildContext context,
    WidgetRef ref,
    Duration duration,
  ) async {
    await ref
        .read(eventMuteRepositoryProvider)
        .muteEvent(
          uid: uid,
          eventId: eventId,
          mutedUntil: clock.now().toUtc().add(duration),
        );
    if (context.mounted) Navigator.of(context).pop();
  }
}
