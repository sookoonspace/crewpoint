import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// The three statuses that may use status colour (Spec #186 Req 10).
enum CpStatus { done, due, overdue }

/// A status label: always an icon and a colour together, so status never
/// rests on colour alone. Green means done or paid, amber due, red overdue.
class CpStatusChip extends StatelessWidget {
  const CpStatusChip({super.key, required this.status, required this.label});

  final CpStatus status;

  /// What the status says, for example "Due Fri" or "Paid".
  final String label;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final (fg, bg, icon) = switch (status) {
      CpStatus.done => (cp.colors.done, cp.colors.doneSoft, CpIcons.statusDone),
      CpStatus.due => (cp.colors.due, cp.colors.dueSoft, CpIcons.statusDue),
      CpStatus.overdue => (
        cp.colors.overdue,
        cp.colors.overdueSoft,
        CpIcons.statusOverdue,
      ),
    };
    return _Pill(background: bg, foreground: fg, icon: icon, label: label);
  }
}

/// How a [CpTag] looks.
enum CpTagTone {
  /// Accent tint: a state worth noticing, such as Published or Live.
  accent,

  /// Outline only: a quiet fact, such as Draft or Child.
  quiet,
}

/// A label that is not a status: an event's state or a small fact. Never
/// green, amber or red.
class CpTag extends StatelessWidget {
  const CpTag({
    super.key,
    required this.label,
    this.tone = CpTagTone.accent,
    this.icon,
    this.dot = false,
  });

  final String label;
  final CpTagTone tone;
  final IconData? icon;

  /// A small dot before the label, for something happening now.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final accent = tone == CpTagTone.accent;
    return _Pill(
      background: accent ? cp.colors.accentSoft : Colors.transparent,
      foreground: accent ? cp.colors.accent : cp.colors.textMuted,
      border: accent ? null : cp.colors.border,
      icon: icon,
      dot: dot,
      label: label,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.background,
    required this.foreground,
    required this.label,
    this.icon,
    this.border,
    this.dot = false,
  });

  final Color background;
  final Color foreground;
  final Color? border;
  final IconData? icon;
  final bool dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: cp.sizes.chipHeight),
        padding: EdgeInsets.symmetric(
          horizontal: cp.space.md - cp.space.xs / 2,
          vertical: cp.space.xs / 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: cp.radii.pill,
          border: border == null
              ? null
              : Border.all(color: border!, width: cp.sizes.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: cp.space.xs,
          children: [
            if (dot)
              Container(
                width: cp.space.sm - 1,
                height: cp.space.sm - 1,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
            if (icon != null)
              Icon(icon, size: cp.sizes.iconXs + 1, color: foreground),
            Flexible(
              child: Text(
                label,
                style: cp.type.labelMedium.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
