import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A section title with an optional count or link on the right, such as
/// "Up next" with "Schedule ›".
class CpSectionHeader extends StatelessWidget {
  const CpSectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback.',
       );

  final String title;

  /// A quiet count or note on the right, such as "41 families".
  final String? trailingText;

  /// A link on the right, such as "All tasks".
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: cp.space.xxl),
      child: Row(
        spacing: cp.space.sm,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: cp.type.titleLarge.copyWith(color: cp.colors.text),
              ),
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText!,
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
          if (actionLabel != null)
            Semantics(
              button: true,
              label: actionLabel,
              child: InkWell(
                key: actionKey,
                onTap: onAction,
                borderRadius: cp.radii.sm,
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
                    child: Padding(
                      padding: EdgeInsets.only(left: cp.space.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel!,
                            style: cp.type.labelLarge.copyWith(
                              color: cp.colors.accent,
                            ),
                          ),
                          Icon(
                            CpIcons.chevronRight,
                            size: cp.sizes.iconSm + 2,
                            color: cp.colors.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
