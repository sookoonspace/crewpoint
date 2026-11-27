import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// The icon and colour for a registration status (Req 71: status shown
/// with an icon and colour together), with its name for screen readers.
(IconData, Color) _look(CpTokens cp, String status) => switch (status) {
  'submitted' => (CpIcons.statusDone, cp.colors.done),
  'pending' => (CpIcons.statusDoing, cp.colors.due),
  'waitlisted' => (CpIcons.placesFull, cp.colors.due),
  'cancelled' => (CpIcons.blocked, cp.colors.overdue),
  _ => (CpIcons.statusTodo, cp.colors.textMuted),
};

class RegistrationStatusIcon extends StatelessWidget {
  const RegistrationStatusIcon({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final (icon, color) = _look(cp, status);
    return Icon(
      icon,
      size: cp.sizes.iconMd,
      color: color,
      semanticLabel: context.strings.committee.status(status),
    );
  }
}

/// A registration status as a tag, with its icon.
class RegistrationStatusTag extends StatelessWidget {
  const RegistrationStatusTag({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, _) = _look(context.cp, status);
    return CpTag(
      label: context.strings.committee.status(status),
      icon: icon,
      tone: status == 'submitted' ? CpTagTone.accent : CpTagTone.quiet,
    );
  }
}
