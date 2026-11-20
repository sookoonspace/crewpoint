import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

enum CpButtonVariant {
  /// The screen's main action: filled accent.
  primary,

  /// Another action beside a primary one: outlined, accent text.
  secondary,

  /// A quiet action: accent text only.
  text,

  /// Removes or ends something: filled red. Confirm it first.
  destructive,
}

/// A button in one of four variants. While [busy] it shows a spinner,
/// ignores taps and reads as unavailable, so a save cannot run
/// twice. With [onPressed] null it is disabled.
class CpButton extends StatelessWidget {
  const CpButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CpButtonVariant.primary,
    this.icon,
    this.leading,
    this.busy = false,
    this.expand = false,
  }) : assert(icon == null || leading == null, 'Give an icon or a leading.');

  const CpButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.busy = false,
    this.expand = false,
  }) : assert(icon == null || leading == null, 'Give an icon or a leading.'),
       variant = CpButtonVariant.secondary;

  const CpButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
  }) : leading = null,
       variant = CpButtonVariant.text;

  const CpButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = false,
  }) : leading = null,
       variant = CpButtonVariant.destructive;

  final String label;
  final VoidCallback? onPressed;
  final CpButtonVariant variant;
  final IconData? icon;

  /// A picture before the label in place of [icon], such as a brand's
  /// logo, sized to the icon.
  final Widget? leading;

  /// Working: shows a spinner and ignores taps.
  final bool busy;

  /// Fills the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final c = cp.colors;
    final (bg, fg, border) = switch (variant) {
      CpButtonVariant.primary => (c.accent, c.onAccent, null),
      CpButtonVariant.secondary => (c.surface, c.accent, c.border),
      CpButtonVariant.text => (Colors.transparent, c.accent, null),
      CpButtonVariant.destructive => (c.overdue, c.surface, null),
    };
    final enabled = onPressed != null;
    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !busy
            ? (variant == CpButtonVariant.text ? Colors.transparent : c.fill)
            : bg,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) && !busy ? c.textMuted : fg,
      ),
      overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.1)),
      side: WidgetStatePropertyAll(
        border == null
            ? BorderSide.none
            : BorderSide(color: border, width: cp.sizes.hairline),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: cp.radii.md),
      ),
      minimumSize: WidgetStatePropertyAll(
        Size(cp.sizes.tapMin, cp.sizes.tapMin),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: variant == CpButtonVariant.text
              ? cp.space.sm
              : cp.space.lg + cp.space.xs / 2,
          vertical: cp.space.sm,
        ),
      ),
      textStyle: WidgetStatePropertyAll(cp.type.labelLarge),
      elevation: const WidgetStatePropertyAll(0),
    );
    final lead = busy
        ? SizedBox.square(
            dimension: cp.sizes.iconMd - 2,
            child: CircularProgressIndicator(
              strokeWidth: cp.sizes.avatarRing,
              color: fg,
            ),
          )
        : leading != null
        ? SizedBox.square(dimension: cp.sizes.iconMd, child: leading)
        : icon == null
        ? null
        : Icon(icon, size: cp.sizes.iconMd);
    final button = TextButton(
      style: style,
      // Busy keeps the button looking enabled but drops taps.
      onPressed: busy ? () {} : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: cp.space.sm,
        children: [
          ?lead,
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled && !busy,
      label: label,
      excludeSemantics: true,
      onTap: enabled && !busy ? onPressed : null,
      child: IgnorePointer(
        ignoring: busy,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
