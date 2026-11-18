import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A single accent arc showing how much of something is done, such as
/// 18 of 26 tasks.
class CpProgressRing extends StatelessWidget {
  const CpProgressRing({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.size,
    this.strokeWidth,
  });

  /// From 0 to 1; values outside are clamped.
  final double value;

  /// What the ring shows, for screen readers, such as "18 of 26 done".
  final String semanticLabel;

  /// Defaults to the small ring size.
  final double? size;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final side = size ?? cp.sizes.ringSm;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(
          painter: _RingPainter(
            value: value.clamp(0, 1).toDouble(),
            stroke: strokeWidth ?? cp.sizes.ringStroke,
            track: cp.colors.border,
            fill: cp.colors.accent,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.fill,
  });

  final double value;
  final double stroke;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        paint
          ..color = fill
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.track != track ||
      old.fill != fill;
}
