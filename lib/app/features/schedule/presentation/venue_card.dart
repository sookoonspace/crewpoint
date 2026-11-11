import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A venue's name, address or "to be announced", directions, and a map
/// button (Req 49). [venue] null means the location is to be announced.
class VenueCard extends ConsumerWidget {
  const VenueCard({super.key, required this.venue, this.children = const []});

  final EventVenue? venue;

  /// Shown below the venue, such as its sessions.
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.schedule;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final v = venue;
    final link = v == null ? null : mapLinkFor(v);
    final id = v?.id ?? 'none';
    final directions = v?.directions?.trim() ?? '';

    return Card(
      key: Key('schedule.venue.$id'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Row(
              spacing: AppSpacing.sm,
              children: [
                Icon(AppIcons.place, color: theme.colorScheme.primary),
                Expanded(
                  child: Text(
                    v?.name ?? strings.noVenue,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (v != null)
              Text(
                v.addressTba ? strings.addressTba : v.address!.trim(),
                key: Key('schedule.venue.$id.address'),
                style: muted,
              ),
            if (directions.isNotEmpty)
              Semantics(
                label: strings.directions,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.sm,
                  children: [
                    Icon(
                      AppIcons.directions,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    Expanded(
                      child: Text(
                        directions,
                        key: Key('schedule.venue.$id.directions'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (link != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: Key('schedule.venue.$id.map'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => ref.read(urlLauncherProvider).launch(link),
                  icon: const Icon(AppIcons.map),
                  label: Text(strings.openMap),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}
