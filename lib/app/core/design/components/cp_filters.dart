import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A search box at the top of a list, such as "Search people". The caller
/// owns [controller] and disposes it.
class CpSearchField extends StatelessWidget {
  const CpSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.fieldKey,
    this.onChanged,
    this.autofocus = false,
  });

  /// The placeholder, which is also the field's label for screen readers.
  final String hint;
  final TextEditingController? controller;

  /// The key on the input itself, for tests (`domain.feature.search`).
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final c = cp.colors;
    OutlineInputBorder border(Color color, {double? width}) =>
        OutlineInputBorder(
          borderRadius: cp.radii.md,
          borderSide: BorderSide(
            color: color,
            width: width ?? cp.sizes.hairline,
          ),
        );
    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: cp.type.bodyLarge.copyWith(color: c.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: cp.type.bodyLarge.copyWith(color: c.textMuted),
        filled: true,
        fillColor: c.surface,
        isDense: true,
        constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
        contentPadding: EdgeInsets.symmetric(
          horizontal: cp.space.md,
          vertical: cp.space.md,
        ),
        prefixIcon: Icon(
          CpIcons.actionSearch,
          size: cp.sizes.iconMd,
          color: c.textMuted,
        ),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.accent, width: cp.sizes.avatarRing),
      ),
    );
  }
}

/// One filter above a list, such as "Group ⌄" or "All". Off, it is an
/// outlined pill that opens a choice ([menu] adds the ⌄); on, it is filled
/// and shows what was chosen, with a × to clear it when [onClear] is given.
class CpFilterChip extends StatelessWidget {
  const CpFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.menu = false,
    this.onTap,
    this.onClear,
    this.clearKey,
    this.clearTooltip,
  });

  final String label;
  final bool selected;

  /// Whether tapping opens a list of choices, shown by a ⌄.
  final bool menu;
  final VoidCallback? onTap;

  /// Clears the filter, shown as a × on a selected chip.
  final VoidCallback? onClear;
  final Key? clearKey;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final c = cp.colors;
    final fg = selected ? c.accent : c.text;
    final shape = RoundedRectangleBorder(
      borderRadius: cp.radii.pill,
      side: BorderSide(
        color: selected ? c.accentSoft : c.border,
        width: cp.sizes.hairline,
      ),
    );
    final pill = Material(
      color: selected ? c.accentSoft : c.surface,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: cp.sizes.tapMin - cp.space.sm),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: cp.space.md + 2,
              end: onClear != null && selected ? cp.space.xs : cp.space.md + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: cp.space.xs,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: cp.type.titleSmall.copyWith(
                      color: fg,
                      fontSize: cp.type.labelLarge.fontSize! - 1,
                    ),
                  ),
                ),
                if (menu && !(selected && onClear != null))
                  Icon(CpIcons.chevronDown, size: cp.sizes.iconSm, color: fg),
                if (selected && onClear != null)
                  // Its own button, at least 40 px, so clearing does not
                  // reopen the choice.
                  IconButton(
                    key: clearKey,
                    tooltip: clearTooltip,
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(
                      width: cp.sizes.tapMin - cp.space.sm,
                      height: cp.sizes.tapMin - cp.space.sm,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(CpIcons.actionClear, size: cp.sizes.iconSm, color: fg),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        // The transparent margin above and below takes the tap too, so the
        // target is at least 48 px while the pill looks lighter.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: cp.space.xs),
          child: pill,
        ),
      ),
    );
  }
}
