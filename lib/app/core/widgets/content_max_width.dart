import 'package:flutter/widgets.dart';

/// Centers + clamps its [child] to [maxWidth] when the available width
/// exceeds [maxWidth], otherwise passes the child's intrinsic sizing
/// through. Used as the canonical body-clamp on every routed screen.
///
/// `Align(alignment) > ConstrainedBox(maxWidth: maxWidth) > child` —
/// no [LayoutBuilder]. [ConstrainedBox] self-clamps without rebuilding
/// the subtree on resize.
class ContentMaxWidth extends StatelessWidget {
  const ContentMaxWidth({
    super.key,
    required this.maxWidth,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final double maxWidth;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
