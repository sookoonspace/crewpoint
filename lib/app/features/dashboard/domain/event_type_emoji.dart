import 'package:flutter/widgets.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// The icon for an older event's type name. Single source of truth for
/// `EventTile`, `ConversationTile` and anywhere the type needs a glyph.
IconData iconForEventType(String? displayType) => switch (displayType) {
  'trip' => CpIcons.eventTrip,
  'project' => CpIcons.eventProject,
  'social' => CpIcons.eventSocial,
  _ => CpIcons.event,
};

/// A template's icon, by the `icon` name in its JSON file (#89).
IconData iconForTemplate(String icon) => switch (icon) {
  'celebration' => CpIcons.templateCelebration,
  'heart' => CpIcons.templateHeart,
  'bat' => CpIcons.templateBat,
  'flag' => CpIcons.templateFlag,
  'groups' => CpIcons.templateGroups,
  _ => CpIcons.templateAdd,
};

/// The icon on an event's banner when it has no cover photo (Spec #186
/// Req 44, ledger L21): its template's icon, else its older type's, else a
/// plain event icon. [templateIcons] maps template IDs to icon names; an
/// event from a saved template carries its base template's ID. Blank, the
/// default for events from before templates, has no icon of its own here.
IconData eventIcon(EventModel event, Map<String, String> templateIcons) {
  final templateIcon = event.templateId == EventModel.defaultTemplateId
      ? null
      : templateIcons[event.templateId];
  if (templateIcon != null) return iconForTemplate(templateIcon);
  final type = event.displayType;
  if (type != null && type.isNotEmpty) return iconForEventType(type);
  return CpIcons.event;
}
