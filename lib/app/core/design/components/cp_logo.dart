import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// The CrewPoint mark: a hub with its crew around it, drawn from the colour
/// tokens so it follows light and dark (Spec #186 Req 9 keeps the shape).
class CpLogo extends StatelessWidget {
  const CpLogo({super.key, required this.size, this.semanticLabel});

  final double size;

  /// Read by screen readers; null hides the mark from them, as beside the
  /// product name.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.cp.colors;
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(
          background: c.surface,
          ink: c.text,
          accent: c.accent,
          soft: c.accentSoft,
          muted: Color.lerp(c.accent, c.surface, 0.45)!,
          faint: Color.lerp(c.accent, c.surface, 0.7)!,
        ),
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: mark)
        : Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({
    required this.background,
    required this.ink,
    required this.accent,
    required this.soft,
    required this.muted,
    required this.faint,
  });

  final Color background;
  final Color ink;
  final Color accent;
  final Color soft;
  final Color muted;
  final Color faint;

  // The mark on a 1024 grid, as in the mockups.
  static const _hub = Offset(538, 495);
  static const _crew = [
    (Offset(379, 172), 48.0, 0),
    (Offset(740, 180), 67.0, 1),
    (Offset(254, 354), 105.0, 2),
    (Offset(833, 374), 79.0, 3),
    (Offset(291, 715), 180.0, 0),
    (Offset(853, 669), 48.0, 0),
    (Offset(695, 806), 105.0, 2),
  ];
  static const _dots = [
    (Offset(339, 403), 41.0),
    (Offset(313, 678), 56.0),
    (Offset(579, 790), 41.0),
  ];
  static const _spokes = [
    Offset(379, 172),
    Offset(740, 180),
    Offset(339, 403),
    Offset(833, 374),
    Offset(313, 678),
    Offset(853, 669),
    Offset(579, 790),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1024;
    canvas
      ..save()
      ..scale(scale)
      ..drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()..color = background,
      );
    final fills = [accent, soft, muted, faint];
    for (final (centre, radius, tone) in _crew) {
      canvas.drawCircle(centre, radius, Paint()..color = fills[tone]);
    }
    final line = Paint()
      ..color = ink
      ..strokeWidth = 10;
    for (final end in _spokes) {
      canvas.drawLine(_hub, end, line);
    }
    final dot = Paint()..color = ink;
    for (final (centre, radius) in _dots) {
      canvas.drawCircle(centre, radius, dot);
    }
    canvas
      ..drawCircle(_hub, 97, dot)
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.background != background ||
      old.ink != ink ||
      old.accent != accent ||
      old.soft != soft;
}
