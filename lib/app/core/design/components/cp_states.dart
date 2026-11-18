import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// Nothing here yet: an icon, a title, a short hint and an optional action.
class CpEmptyState extends StatelessWidget {
  const CpEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback.',
       );

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return _StateLayout(
      icon: icon,
      iconColor: cp.colors.accent,
      iconBackground: cp.colors.accentSoft,
      title: title,
      message: message,
      action: actionLabel == null
          ? null
          : FilledButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
    );
  }
}

/// Something failed to load: what went wrong, what to do, and a retry.
class CpErrorState extends StatelessWidget {
  const CpErrorState({
    super.key,
    required this.title,
    required this.retryLabel,
    required this.onRetry,
    this.message,
    this.icon = CpIcons.statusError,
    this.retryKey,
  });

  final String title;
  final String? message;
  final String retryLabel;
  final VoidCallback onRetry;
  final IconData icon;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return _StateLayout(
      icon: icon,
      iconColor: cp.colors.overdue,
      iconBackground: cp.colors.overdueSoft,
      title: title,
      message: message,
      liveRegion: true,
      action: OutlinedButton.icon(
        key: retryKey,
        onPressed: onRetry,
        icon: Icon(CpIcons.actionRetry, size: cp.sizes.iconMd),
        label: Text(retryLabel),
      ),
    );
  }
}

/// Loading: a spinner with an optional label, or placeholder rows shaped
/// like the list that is coming ([CpLoadingState.rows]).
class CpLoadingState extends StatelessWidget {
  const CpLoadingState({super.key, required this.semanticLabel, this.label})
    : rows = 0;

  /// Placeholder rows, for a list that is about to appear.
  const CpLoadingState.rows({
    super.key,
    required this.semanticLabel,
    this.rows = 3,
  }) : label = null;

  /// Read by screen readers, such as "Loading people".
  final String semanticLabel;

  /// Shown under the spinner.
  final String? label;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    if (rows > 0) {
      return Semantics(
        label: semanticLabel,
        liveRegion: true,
        excludeSemantics: true,
        child: Column(
          spacing: cp.space.sm,
          children: [for (var i = 0; i < rows; i++) const _SkeletonRow()],
        ),
      );
    }
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(cp.space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: cp.space.md,
            children: [
              SizedBox.square(
                dimension: cp.sizes.iconXl,
                child: CircularProgressIndicator(
                  strokeWidth: cp.sizes.ringStroke - 2,
                  color: cp.colors.accent,
                  backgroundColor: cp.colors.border,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    Widget bar(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: cp.sizes.skeletonLine,
        decoration: BoxDecoration(
          color: cp.colors.fill,
          borderRadius: cp.radii.xs,
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.all(cp.space.lg),
      decoration: BoxDecoration(
        color: cp.colors.surface,
        borderRadius: cp.radii.md,
        border: Border.all(color: cp.colors.border, width: cp.sizes.hairline),
      ),
      child: Row(
        spacing: cp.space.md,
        children: [
          Container(
            width: cp.sizes.avatarMd,
            height: cp.sizes.avatarMd,
            decoration: BoxDecoration(
              color: cp.colors.fill,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: cp.space.sm,
              children: [bar(0.6), bar(0.35)],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.message,
    this.action,
    this.liveRegion = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? message;
  final Widget? action;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(cp.space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: cp.space.md,
          children: [
            ExcludeSemantics(
              child: Container(
                width: cp.sizes.avatarLg,
                height: cp.sizes.avatarLg,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: cp.sizes.iconXl, color: iconColor),
              ),
            ),
            Semantics(
              liveRegion: liveRegion,
              child: Column(
                spacing: cp.space.xs,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: cp.type.titleLarge.copyWith(color: cp.colors.text),
                  ),
                  if (message != null)
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: cp.type.bodyMedium.copyWith(
                        color: cp.colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (action != null)
              Padding(
                padding: EdgeInsets.only(top: cp.space.sm),
                child: action,
              ),
          ],
        ),
      ),
    );
  }
}
