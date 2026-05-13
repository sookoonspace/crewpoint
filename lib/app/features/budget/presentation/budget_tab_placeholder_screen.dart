import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';

/// V1 cross-event Budget tab — empty-state-only. Real aggregation is
/// scoped to a future PR; this tab just funnels users back to the
/// Dashboard.
class BudgetTabPlaceholderScreen extends StatelessWidget {
  const BudgetTabPlaceholderScreen({super.key, this.onOpenDashboard});

  /// Navigation seam — tests inject a capturing callback because they run
  /// without a real `GoRouter` ancestor.
  final VoidCallback? onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: EmptyStatePlaceholder(
        title: s.budget.tabEmptyTitle,
        subtitle: s.budget.tabEmptySubtitle,
        ctaLabel: s.tasks.openDashboardCta,
        onCta: () {
          final cb = onOpenDashboard;
          if (cb != null) {
            cb();
          } else {
            context.go(AppRoutes.dashboard);
          }
        },
      ),
    );
  }
}
