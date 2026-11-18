import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/scale.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// One button on the right of a [CpTopBar].
class CpTopBarAction {
  const CpTopBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.key,
    this.primary = false,
  });

  final IconData icon;

  /// Also the button's screen reader label.
  final String tooltip;
  final VoidCallback onPressed;
  final Key? key;

  /// The screen's main action, drawn as a filled accent circle (an "Add").
  /// At most one per bar.
  final bool primary;
}

/// The bar at the top of a screen: back or close on the left, a title, and
/// up to three actions on the right. Use as `Scaffold.appBar`.
class CpTopBar extends StatelessWidget implements PreferredSizeWidget {
  const CpTopBar({
    super.key,
    this.title,
    this.leadingIcon = CpIcons.actionBack,
    this.leadingTooltip,
    this.onLeading,
    this.leadingKey,
    this.actions = const [],
  });

  final String? title;

  /// Back by default; pass [CpIcons.actionClose] for a full-screen form.
  final IconData leadingIcon;

  /// The back or close button's label, such as "Back". Without it and
  /// [onLeading] the bar has no leading button.
  final String? leadingTooltip;
  final VoidCallback? onLeading;
  final Key? leadingKey;
  final List<CpTopBarAction> actions;

  @override
  // Read without a context, so straight from the scale.
  Size get preferredSize => const Size.fromHeight(CpScale.topBar52);

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= 3, 'Move further actions into a menu.');
    final cp = context.cp;
    return Material(
      color: cp.colors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: cp.sizes.topBarHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: cp.space.xs),
            child: Row(
              children: [
                if (onLeading != null)
                  _BarButton(
                    key: leadingKey,
                    icon: leadingIcon,
                    tooltip: leadingTooltip ?? '',
                    onPressed: onLeading!,
                  )
                else
                  SizedBox(width: cp.space.md),
                Expanded(
                  child: title == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.only(left: cp.space.xs),
                          child: Semantics(
                            header: true,
                            child: Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: cp.type.titleLarge.copyWith(
                                color: cp.colors.text,
                              ),
                            ),
                          ),
                        ),
                ),
                for (final a in actions)
                  _BarButton(
                    key: a.key,
                    icon: a.icon,
                    tooltip: a.tooltip,
                    onPressed: a.onPressed,
                    primary: a.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final tap = cp.sizes.tapMin;
    if (!primary) {
      return IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: cp.sizes.iconLg - 2, color: cp.colors.text),
        constraints: BoxConstraints.tightFor(width: tap, height: tap),
      );
    }
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: tap / 2,
          child: SizedBox.square(
            dimension: tap,
            child: Center(
              child: Container(
                width: tap - cp.space.md,
                height: tap - cp.space.md,
                decoration: BoxDecoration(
                  color: cp.colors.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: cp.sizes.iconLg - 2,
                  color: cp.colors.onAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
