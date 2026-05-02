import 'package:flutter/material.dart';

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
          icon: Icon(
            Icons.dashboard_outlined,
            key: Key('shell.rail.dashboard'),
          ),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.task_outlined, key: Key('shell.rail.tasks')),
          selectedIcon: Icon(Icons.task),
          label: Text('Tasks'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.chat_outlined, key: Key('shell.rail.chat')),
          selectedIcon: Icon(Icons.chat),
          label: Text('Chat'),
        ),
        NavigationRailDestination(
          icon: Icon(
            Icons.account_balance_wallet_outlined,
            key: Key('shell.rail.budget'),
          ),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: Text('Budget'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline, key: Key('shell.rail.profile')),
          selectedIcon: Icon(Icons.person),
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
              icon: const Icon(Icons.logout),
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
          key: Key('shell.bar.dashboard'),
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          key: Key('shell.bar.tasks'),
          icon: Icon(Icons.task_outlined),
          selectedIcon: Icon(Icons.task),
          label: 'Tasks',
        ),
        NavigationDestination(
          key: Key('shell.bar.chat'),
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        NavigationDestination(
          key: Key('shell.bar.budget'),
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Budget',
        ),
        NavigationDestination(
          key: Key('shell.bar.profile'),
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
