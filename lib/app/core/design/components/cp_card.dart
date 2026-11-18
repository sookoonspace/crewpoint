import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A surface with a hairline border, the faintest shadow and rounded
/// corners: the container for rows, stats and form sections.
///
/// With [onTap] the whole card is one button.
class CpCard extends StatelessWidget {
  const CpCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Inside spacing. Defaults to none, so lists of rows run edge to edge;
  /// pass `EdgeInsets.all(context.cp.space.lg)` for free content.
  final EdgeInsetsGeometry? padding;

  /// Read instead of the card's content when it is tappable.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final shape = RoundedRectangleBorder(
      borderRadius: cp.radii.md,
      side: BorderSide(color: cp.colors.border, width: cp.sizes.hairline),
    );
    Widget content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (onTap != null) {
      content = Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: semanticLabel == null
              ? content
              : ExcludeSemantics(child: content),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: cp.radii.md,
        boxShadow: cp.shadows.card,
      ),
      child: Material(
        color: cp.colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
