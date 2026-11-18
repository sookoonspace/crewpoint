import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/cp_logo.dart';
import 'package:crewpoint_app/app/core/design/layout/breakpoints.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// One top-level destination in the [CpShell].
@immutable
class CpNavDestination {
  const CpNavDestination({
    required this.id,
    required this.icon,
    required this.label,
    this.badge = 0,
  });

  /// Names its keys: `shell.bar.{id}` and `shell.rail.{id}`, and
  /// `….badge` for its count.
  final String id;
  final IconData icon;
  final String label;

  /// An unread count; zero shows nothing, 100 and over shows "99+".
  final int badge;
}

/// The app's frame (Spec #186 Req 22): under 840 px one column with a bottom
/// bar, the column capped and centred from 600 px; from 840 px a left
/// sidebar instead. [body] keeps its place in the tree across the switch,
/// so its routes, state and scroll positions survive a resize.
class CpShell extends StatelessWidget {
  const CpShell({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onSignOut,
    required this.signOutLabel,
    required this.appName,
    required this.body,
  });

  final List<CpNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSignOut;
  final String signOutLabel;

  /// Beside the logo in the sidebar.
  final String appName;
  final Widget body;

  /// Whether [context] is wide enough for the sidebar and list and detail.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.mediumMax;

  static const _bodyKey = ValueKey('shell.body');

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= Breakpoints.mediumMax;
        // From 600 to 839 px the single column stays phone-width, centred.
        final cap = !wide && width >= Breakpoints.compactMax
            ? cp.sizes.phoneColumn + 2 * cp.space.xl
            : double.infinity;
        return Scaffold(
          backgroundColor: cp.colors.background,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                _Sidebar(
                  destinations: destinations,
                  currentIndex: currentIndex,
                  onSelected: onDestinationSelected,
                  onSignOut: onSignOut,
                  signOutLabel: signOutLabel,
                  appName: appName,
                ),
              Expanded(
                key: _bodyKey,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    key: const Key('shell.column'),
                    constraints: BoxConstraints(maxWidth: cap),
                    child: body,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : _BottomBar(
                  destinations: destinations,
                  currentIndex: currentIndex,
                  onSelected: onDestinationSelected,
                ),
        );
      },
    );
  }
}

String _badgeText(int count) => count >= 100 ? '99+' : '$count';

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Container(
      constraints: BoxConstraints(
        minWidth: cp.sizes.iconMd,
        minHeight: cp.sizes.iconMd,
      ),
      padding: EdgeInsets.symmetric(horizontal: cp.space.xs + 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cp.colors.accent,
        borderRadius: cp.radii.pill,
      ),
      child: Text(
        _badgeText(count),
        textScaler: TextScaler.noScaling,
        style: cp.type.labelSmall.copyWith(
          color: cp.colors.onAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<CpNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Material(
      key: const Key('shell.bar'),
      color: cp.colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cp.colors.border, width: cp.sizes.hairline),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _BarItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final CpNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final colour = selected ? cp.colors.accent : cp.colors.textMuted;
    final id = destination.id;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.badge > 0
          ? '${destination.label}, ${_badgeText(destination.badge)}'
          : destination.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        key: Key('shell.bar.$id'),
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: cp.sizes.tapMin + cp.space.md),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: cp.space.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: cp.space.xs - 1,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: cp.motion.fast,
                      width: cp.sizes.tapMin + cp.space.sm,
                      height: cp.sizes.iconXl - 2,
                      decoration: BoxDecoration(
                        color: selected
                            ? cp.colors.accentSoft
                            : Colors.transparent,
                        borderRadius: cp.radii.pill,
                      ),
                      child: Icon(
                        destination.icon,
                        size: cp.sizes.iconLg - 2,
                        color: colour,
                      ),
                    ),
                    if (destination.badge > 0)
                      Positioned(
                        right: cp.space.xs,
                        top: -cp.space.xs,
                        child: _Badge(
                          key: Key('shell.bar.$id.badge'),
                          count: destination.badge,
                        ),
                      ),
                  ],
                ),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cp.type.labelSmall.copyWith(
                    color: colour,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    required this.onSignOut,
    required this.signOutLabel,
    required this.appName,
  });

  final List<CpNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;
  final String signOutLabel;
  final String appName;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Material(
      key: const Key('shell.sidebar'),
      color: cp.colors.surface,
      child: Container(
        width: cp.sizes.sidebar,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: cp.colors.border,
              width: cp.sizes.hairline,
            ),
          ),
        ),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: cp.space.md,
              vertical: cp.space.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.xs,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    cp.space.sm,
                    0,
                    cp.space.sm,
                    cp.space.lg,
                  ),
                  child: Row(
                    spacing: cp.space.md - 2,
                    children: [
                      CpLogo(size: cp.sizes.iconXl),
                      Flexible(
                        child: Text(
                          appName,
                          style: cp.type.titleLarge.copyWith(
                            color: cp.colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < destinations.length; i++)
                  _SidebarItem(
                    itemKey: Key('shell.rail.${destinations[i].id}'),
                    badgeKey: Key('shell.rail.${destinations[i].id}.badge'),
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    badge: destinations[i].badge,
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                const Spacer(),
                _SidebarItem(
                  itemKey: const Key('shell.rail.signOut'),
                  icon: CpIcons.actionLogout,
                  label: signOutLabel,
                  selected: false,
                  onTap: onSignOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.itemKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    this.badgeKey,
  });

  final Key itemKey;
  final Key? badgeKey;
  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final colour = selected ? cp.colors.accent : cp.colors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, ${_badgeText(badge)}' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? cp.colors.accentSoft : Colors.transparent,
        borderRadius: cp.radii.sm,
        child: InkWell(
          key: itemKey,
          onTap: onTap,
          borderRadius: cp.radii.sm,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: cp.space.md - 2),
              child: Row(
                spacing: cp.space.md,
                children: [
                  Icon(icon, size: cp.sizes.iconMd, color: colour),
                  Expanded(
                    child: Text(
                      label,
                      style: cp.type.titleSmall.copyWith(color: colour),
                    ),
                  ),
                  if (badge > 0) _Badge(key: badgeKey, count: badge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
