import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';

/// A venue's name, address or "to be announced", directions, and a map
/// button (Req 49), with its sessions below as rows. [venue] null means the
/// location is to be announced.
class VenueCard extends ConsumerWidget {
  const VenueCard({super.key, required this.venue, this.children = const []});

  final EventVenue? venue;

  /// Rows below the venue, such as its sessions.
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.schedule;
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    final v = venue;
    final link = v == null ? null : mapLinkFor(v);
    final id = v?.id ?? 'none';
    final directions = v?.directions?.trim() ?? '';

    final header = Padding(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: [
          Row(
            spacing: cp.space.md,
            children: [
              Container(
                width: cp.sizes.iconTile,
                height: cp.sizes.iconTile,
                decoration: BoxDecoration(
                  color: cp.colors.accentSoft,
                  borderRadius: cp.radii.sm,
                ),
                child: Icon(
                  CpIcons.place,
                  size: cp.sizes.iconMd,
                  color: cp.colors.accent,
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    v?.name ?? strings.noVenue,
                    style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                  ),
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
                spacing: cp.space.sm,
                children: [
                  Icon(
                    CpIcons.directions,
                    size: cp.sizes.iconMd,
                    color: cp.colors.textMuted,
                  ),
                  Expanded(
                    child: Text(
                      directions,
                      key: Key('schedule.venue.$id.directions'),
                      style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                    ),
                  ),
                ],
              ),
            ),
          if (link != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CpButton.secondary(
                key: Key('schedule.venue.$id.map'),
                label: strings.openMap,
                icon: CpIcons.map,
                onPressed: () => ref.read(urlLauncherProvider).launch(link),
              ),
            ),
        ],
      ),
    );

    return CpCard(
      key: Key('schedule.venue.$id'),
      child: children.isEmpty
          ? header
          : CpRowGroup(children: [header, ...children]),
    );
  }
}
