import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// One row of a list: optional leading (avatar, icon tile, time), a title,
/// an optional subtitle, and an optional trailing (chip, amount, chevron).
///
/// With [onTap] the row is one button and shows a chevron unless
/// [trailing] is given.
class CpListRow extends StatelessWidget {
  const CpListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// The chosen row in a list and detail layout.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final trail =
        trailing ??
        (onTap == null
            ? null
            : Icon(
                CpIcons.chevronRight,
                size: cp.sizes.iconMd,
                color: cp.colors.textMuted,
              ));
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cp.space.lg,
          vertical: cp.space.md,
        ),
        child: Row(
          spacing: cp.space.md,
          children: [
            ?leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: cp.space.xs / 2,
                children: [
                  Text(
                    title,
                    style: cp.type.titleSmall.copyWith(color: cp.colors.text),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: cp.type.bodySmall.copyWith(
                        color: cp.colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            ?trail,
          ],
        ),
      ),
    );
    final colored = ColoredBox(
      color: selected ? cp.colors.accentSoft : Colors.transparent,
      child: row,
    );
    if (onTap == null) {
      return MergeSemantics(child: colored);
    }
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, child: colored),
        ),
      ),
    );
  }
}

/// Rows inside one card, divided by hairlines.
class CpRowGroup extends StatelessWidget {
  const CpRowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: cp.sizes.hairline,
              thickness: cp.sizes.hairline,
              color: cp.colors.border,
            ),
          children[i],
        ],
      ],
    );
  }
}
