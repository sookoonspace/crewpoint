import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';

/// At viewports wider than [Breakpoints.compactMax] wraps [child] in a
/// padded Material [Card] so a 480-clamped form column doesn't read as
/// "a tiny floating column in a sea of grey" on desktop. At compact
/// viewports the shell passes the child through unchanged so the mobile
/// layout is preserved.
class FormCardShell extends StatelessWidget {
  const FormCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > Breakpoints.compactMax;
    if (!wide) return child;
    return Card(
      key: const Key('form.card.shell'),
      elevation: 1,
      child: Padding(padding: padding, child: child),
    );
  }
}
