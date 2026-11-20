import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A form's Save at the bottom of the screen, as on the Person form: the
/// surface colour, a top border, and [child] at the end. Use as
/// `Scaffold.bottomNavigationBar`.
class CpSaveBar extends StatelessWidget {
  const CpSaveBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Material(
      color: cp.colors.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cp.colors.border)),
          ),
          child: Padding(
            padding: EdgeInsets.all(cp.space.md),
            // heightFactor 1: the bar is only as tall as its button.
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              heightFactor: 1,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
