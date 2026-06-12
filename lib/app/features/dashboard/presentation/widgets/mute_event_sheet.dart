import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (_) => MuteEventSheet(uid: uid, eventId: eventId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMute = ref.watch(
      eventMuteProvider((uid: uid, eventId: eventId)),
    );
    final activeMute = asyncMute.maybeWhen(data: (m) => m, orElse: () => null);
    final isActive =
        activeMute != null && activeMute.isMutedAt(clock.now().toUtc());

    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isActive ? 'Currently muted' : 'Mute event',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isActive
                ? 'Notifications for this event are paused until '
                      '${_formatUntil(activeMute.mutedUntil)}.'
                : 'Pause all notifications for this event for the selected '
                      "window. You'll still see messages when you open "
                      'the chat.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isActive)
            _DurationButton(
              keyId: 'muteSheet.unmute',
              label: 'Unmute',
              icon: Icons.notifications_active_outlined,
              onTap: () async {
                await ref
                    .read(eventMuteRepositoryProvider)
                    .unmuteEvent(uid: uid, eventId: eventId);
                if (context.mounted) Navigator.of(context).pop();
              },
            )
          else ...[
            _DurationButton(
              keyId: 'muteSheet.duration.1h',
              label: '1 hour',
              icon: Icons.timer_outlined,
              onTap: () => _mute(context, ref, const Duration(hours: 1)),
            ),
            _DurationButton(
              keyId: 'muteSheet.duration.8h',
              label: '8 hours',
              icon: Icons.bedtime_outlined,
              onTap: () => _mute(context, ref, const Duration(hours: 8)),
            ),
            _DurationButton(
              keyId: 'muteSheet.duration.1d',
              label: '1 day',
              icon: Icons.today_outlined,
              onTap: () => _mute(context, ref, const Duration(days: 1)),
            ),
            _DurationButton(
              keyId: 'muteSheet.duration.untilUnmute',
              label: 'Until I unmute',
              icon: Icons.notifications_off_outlined,
              // 10 years is "forever" for practical purposes; the server
              // honours the timestamp literally and the user can always
              // open this sheet again to unmute. Keeps the schema as a
              // single `mutedUntil` field without a separate "indefinite"
              // sentinel.
              onTap: () => _mute(context, ref, const Duration(days: 365 * 10)),
            ),
          ],
        ],
      ),
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

  String _formatUntil(DateTime mutedUntil) {
    final local = mutedUntil.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm ${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _DurationButton extends StatelessWidget {
  const _DurationButton({
    required this.keyId,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String keyId;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OutlinedButton.icon(
        key: Key(keyId),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
