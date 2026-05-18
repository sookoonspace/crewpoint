import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';

/// Compact three-arc progress ring with a centered "{done}/{total}" label.
///
/// Renders three arcs around a circle: done (sage), doing (amber), todo (track).
/// When `total == 0`, renders a neutral empty ring with a "—" label — no
/// division by zero, no "0/0" string.
///
/// Exposes a semantic announcement of all three counts so screen readers
/// communicate the same information the ring does visually.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.todo,
    required this.doing,
    required this.done,
    this.size = AppSizes.progressRingSize,
    this.strokeWidth = 5,
  });

  final int todo;
  final int doing;
  final int done;
  final double size;
  final double strokeWidth;

  int get _total => todo + doing + done;

  String get _label => _total == 0 ? '—' : '$done/$_total';

  String get _semanticLabel => _total == 0
      ? 'No tasks yet'
      : '$done of $_total tasks done, $doing in progress, $todo to do';

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
    );

    return Semantics(
      container: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                todo: todo,
                doing: doing,
                done: done,
                strokeWidth: strokeWidth,
              ),
            ),
            Text(_label, style: labelStyle),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.todo,
    required this.doing,
    required this.done,
    required this.strokeWidth,
  });

  final int todo;
  final int doing;
  final int done;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - strokeWidth) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.lightGrey;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    final total = todo + doing + done;
    if (total == 0) return;

    void drawArc(double startFraction, double sweepFraction, Color color) {
      final start = -math.pi / 2 + startFraction * 2 * math.pi;
      final sweep = sweepFraction * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = color;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    final doneFrac = done / total;
    final doingFrac = doing / total;
    drawArc(0, doneFrac, AppColors.statusDoneFg);
    drawArc(doneFrac, doingFrac, AppColors.statusDoingFg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.todo != todo ||
      old.doing != doing ||
      old.done != done ||
      old.strokeWidth != strokeWidth;
}
