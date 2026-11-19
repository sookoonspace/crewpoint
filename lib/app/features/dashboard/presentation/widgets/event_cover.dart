import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_template.dart';

/// The cover's photo, once read, or null to show the event's icon.
ImageProvider? _photo(WidgetRef ref, EventModel event) {
  final cover = event.cover;
  if (cover == null) return null;
  final bytes = ref.watch(coverBytesProvider(cover)).value;
  return bytes == null ? null : MemoryImage(bytes);
}

/// Template IDs to icon names, once the catalogue has loaded.
Map<String, String> _templateIcons(WidgetRef ref) => {
  for (final t
      in ref.watch(templateCatalogueProvider).value ??
          const <EventTemplateInfo>[])
    t.id: t.icon,
};

/// An event's cover banner, on its home (Spec #186 Req 43, 44).
class EventCoverBanner extends ConsumerWidget {
  const EventCoverBanner({super.key, required this.event, this.height});

  final EventModel event;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = Localizations.localeOf(context).languageCode;
    final template = event.templateId == EventModel.defaultTemplateId
        ? null
        : (ref.watch(templateCatalogueProvider).value ??
                  const <EventTemplateInfo>[])
              .where((t) => t.id == event.templateId)
              .firstOrNull;
    return CpCoverBanner(
      key: Key('event.cover.${event.id}'),
      image: _photo(ref, event),
      icon: eventIcon(event, _templateIcons(ref)),
      label: template?.name(language) ?? event.displayType,
      height: height,
      semanticLabel: context.strings.cover.heading,
    );
  }
}

/// An event's cover as a thumbnail on its list card.
class EventCoverThumb extends ConsumerWidget {
  const EventCoverThumb({super.key, required this.event, this.size});

  final EventModel event;
  final double? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CpCoverThumb(
    key: Key('event.thumb.${event.id}'),
    image: _photo(ref, event),
    icon: eventIcon(event, _templateIcons(ref)),
    size: size,
  );
}
