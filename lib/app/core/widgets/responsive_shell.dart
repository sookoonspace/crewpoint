import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';

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
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSignOut;
  final Widget body;

  static const double _railBreakpoint = 840;

  /// Stable key on the body slot so its [Element] (and therefore branch
  /// state, route stack, and scroll positions) survives the breakpoint
  /// transition when rail siblings are inserted/removed alongside it.
  static const _bodyKey = ValueKey('shell.body');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;
        return Scaffold(
          body: Row(
            children: [
              if (useRail) ...[
                _buildRail(),
                const VerticalDivider(thickness: 1, width: 1),
              ],
              Expanded(key: _bodyKey, child: body),
            ],
          ),
          bottomNavigationBar: useRail ? null : _buildBar(),
        );
      },
    );
  }

  NavigationRail _buildRail() {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      extended: true,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(AppIcons.navHome, key: Key('shell.rail.home')),
          selectedIcon: Icon(AppIcons.navHomeFilled),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(AppIcons.navTasks, key: Key('shell.rail.tasks')),
          selectedIcon: Icon(AppIcons.navTasksFilled),
          label: Text('Tasks'),
        ),
        NavigationRailDestination(
          icon: Icon(AppIcons.navChat, key: Key('shell.rail.chat')),
          selectedIcon: Icon(AppIcons.navChatFilled),
          label: Text('Chat'),
        ),
        NavigationRailDestination(
          icon: Icon(AppIcons.navBudget, key: Key('shell.rail.budget')),
          selectedIcon: Icon(AppIcons.navBudgetFilled),
          label: Text('Budget'),
        ),
        NavigationRailDestination(
          icon: Icon(AppIcons.navProfile, key: Key('shell.rail.profile')),
          selectedIcon: Icon(AppIcons.navProfileFilled),
          label: Text('Profile'),
        ),
      ],
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              key: const Key('shell.rail.signOut'),
              tooltip: 'Sign out',
              icon: const Icon(AppIcons.actionLogout),
              onPressed: onSignOut,
            ),
          ),
        ),
      ),
    );
  }

  NavigationBar _buildBar() {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: const [
        NavigationDestination(
          key: Key('shell.bar.home'),
          icon: Icon(AppIcons.navHome),
          selectedIcon: Icon(AppIcons.navHomeFilled),
          label: 'Home',
        ),
        NavigationDestination(
          key: Key('shell.bar.tasks'),
          icon: Icon(AppIcons.navTasks),
          selectedIcon: Icon(AppIcons.navTasksFilled),
          label: 'Tasks',
        ),
        NavigationDestination(
          key: Key('shell.bar.chat'),
          icon: Icon(AppIcons.navChat),
          selectedIcon: Icon(AppIcons.navChatFilled),
          label: 'Chat',
        ),
        NavigationDestination(
          key: Key('shell.bar.budget'),
          icon: Icon(AppIcons.navBudget),
          selectedIcon: Icon(AppIcons.navBudgetFilled),
          label: 'Budget',
        ),
        NavigationDestination(
          key: Key('shell.bar.profile'),
          icon: Icon(AppIcons.navProfile),
          selectedIcon: Icon(AppIcons.navProfileFilled),
          label: 'Profile',
        ),
      ],
    );
  }
}
