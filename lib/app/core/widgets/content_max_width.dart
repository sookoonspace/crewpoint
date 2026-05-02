import 'package:flutter/widgets.dart';

/// Centers + clamps its [child] to [maxWidth] when the available width
/// exceeds [maxWidth], otherwise passes the child's intrinsic sizing
/// through. Used as the canonical body-clamp on every routed screen.
///
/// `Align(alignment) > ConstrainedBox(maxWidth: maxWidth) > child` —
/// no [LayoutBuilder]. [ConstrainedBox] self-clamps without rebuilding
/// the subtree on resize.
///
/// The constructor [key] is forwarded to the inner [ConstrainedBox] (the
/// element whose rendered width matches the clamp) so layout-regression
/// tests can `find.byKey(...)` and assert on `tester.getSize(...).width`.
class ContentMaxWidth extends StatelessWidget {
  // Constructor [key] is forwarded to the inner [ConstrainedBox] so layout
  // tests can assert on the rendered clamp width directly (otherwise the
  // outer [Align] would always report the viewport width). The widget
  // element itself stays unkeyed by design.
  // ignore: use_key_in_widget_constructors
  const ContentMaxWidth({
    Key? key,
    required this.maxWidth,
    required this.child,
    this.alignment = Alignment.topCenter,
  }) : _clampKey = key;

  final Key? _clampKey;
  final double maxWidth;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        key: _clampKey,
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
