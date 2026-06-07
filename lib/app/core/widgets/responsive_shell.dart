import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Adaptive navigation shell.
///
/// Width < [_railBreakpoint] → bottom [NavigationBar].
/// Width ≥ [_railBreakpoint] → leading [NavigationRail].
///
/// The breakpoint sits at the Material 3 medium → expanded boundary
/// (840 px). Tablet-portrait widths (e.g. 768 px) belong to "bar" UX,
/// not rail; on-screen keyboards eat too much vertical space for a
/// rail to feel right at those sizes.
///
/// The [body] widget is the only child of the underlying [Scaffold] in
/// every layout, so its [Element] identity (and therefore branch state,
/// route stack, and scroll positions) survives a breakpoint transition.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onSignOut,
    required this.body,
    this.tasksBadge = 0,
    this.chatBadge = 0,
    this.budgetBadge = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSignOut;
  final Widget body;

  /// Unread counts surfaced as Material [Badge]s on the bottom-nav / rail.
  /// Zero hides the badge. Driven by `unreadBadgeProvider` at the
  /// composition root (see `app_router.dart`).
  final int tasksBadge;
  final int chatBadge;
  final int budgetBadge;

  static const double _railBreakpoint = 840;

  /// Stable key on the body slot so its [Element] (and therefore branch
  /// state, route stack, and scroll positions) survives the breakpoint
  /// transition when rail siblings are inserted/removed alongside it.
  static const _bodyKey = ValueKey('shell.body');

  @override
  Widget build(BuildContext context) {
    final s = context.strings.nav;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;
        return Scaffold(
          body: Row(
            children: [
              if (useRail) ...[
                _buildRail(s),
                const VerticalDivider(thickness: 1, width: 1),
              ],
              Expanded(key: _bodyKey, child: body),
            ],
          ),
          bottomNavigationBar: useRail ? null : _buildBar(s),
        );
      },
    );
  }

  NavigationRail _buildRail(NavStrings s) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      extended: true,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(AppIcons.navHome, key: Key('shell.rail.home')),
          selectedIcon: const Icon(AppIcons.navHomeFilled),
          label: Text(s.home),
        ),
        NavigationRailDestination(
          icon: _badged(
            const Icon(AppIcons.navTasks, key: Key('shell.rail.tasks')),
            count: tasksBadge,
            badgeKey: const Key('shell.rail.tasks.badge'),
          ),
          selectedIcon: const Icon(AppIcons.navTasksFilled),
          label: Text(s.tasks),
        ),
        NavigationRailDestination(
          icon: _badged(
            const Icon(AppIcons.navChat, key: Key('shell.rail.chat')),
            count: chatBadge,
            badgeKey: const Key('shell.rail.chat.badge'),
          ),
          selectedIcon: const Icon(AppIcons.navChatFilled),
          label: Text(s.chat),
        ),
        NavigationRailDestination(
          icon: _badged(
            const Icon(AppIcons.navBudget, key: Key('shell.rail.budget')),
            count: budgetBadge,
            badgeKey: const Key('shell.rail.budget.badge'),
          ),
          selectedIcon: const Icon(AppIcons.navBudgetFilled),
          label: Text(s.budget),
        ),
        NavigationRailDestination(
          icon: const Icon(AppIcons.navProfile, key: Key('shell.rail.profile')),
          selectedIcon: const Icon(AppIcons.navProfileFilled),
          label: Text(s.profile),
        ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              key: const Key('shell.rail.signOut'),
              tooltip: s.signOutTooltip,
              icon: const Icon(AppIcons.actionLogout),
              onPressed: onSignOut,
            ),
          ),
        ),
      ),
    );
  }

  NavigationBar _buildBar(NavStrings s) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        NavigationDestination(
          key: const Key('shell.bar.home'),
          icon: const Icon(AppIcons.navHome),
          selectedIcon: const Icon(AppIcons.navHomeFilled),
          label: s.home,
        ),
        NavigationDestination(
          key: const Key('shell.bar.tasks'),
          icon: _badged(
            const Icon(AppIcons.navTasks),
            count: tasksBadge,
            badgeKey: const Key('shell.bar.tasks.badge'),
          ),
          selectedIcon: const Icon(AppIcons.navTasksFilled),
          label: s.tasks,
        ),
        NavigationDestination(
          key: const Key('shell.bar.chat'),
          icon: _badged(
            const Icon(AppIcons.navChat),
            count: chatBadge,
            badgeKey: const Key('shell.bar.chat.badge'),
          ),
          selectedIcon: const Icon(AppIcons.navChatFilled),
          label: s.chat,
        ),
        NavigationDestination(
          key: const Key('shell.bar.budget'),
          icon: _badged(
            const Icon(AppIcons.navBudget),
            count: budgetBadge,
            badgeKey: const Key('shell.bar.budget.badge'),
          ),
          selectedIcon: const Icon(AppIcons.navBudgetFilled),
          label: s.budget,
        ),
        NavigationDestination(
          key: const Key('shell.bar.profile'),
          icon: const Icon(AppIcons.navProfile),
          selectedIcon: const Icon(AppIcons.navProfileFilled),
          label: s.profile,
        ),
      ],
    );
  }

  /// Wraps [icon] in a Material [Badge] when [count] > 0; returns [icon]
  /// unmodified when zero so the un-badged path keeps the same widget
  /// identity (matters for the existing key-finder widget tests).
  ///
  /// Counts ≥ 100 are clamped to "99+" so the badge never overflows on
  /// pathologically high inboxes.
  Widget _badged(Widget icon, {required int count, required Key badgeKey}) {
    if (count <= 0) return icon;
    final label = count >= 100 ? '99+' : '$count';
    return Badge(key: badgeKey, label: Text(label), child: icon);
  }
}
