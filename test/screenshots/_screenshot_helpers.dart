import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps every placeholder screenshot in:
///   - a 1-px terracotta border (visible at the edge of the PNG)
///   - a translucent terracotta strip at the bottom-right reading
///     "PLACEHOLDER - replace before public launch"
/// so the artifact is unmistakably not a real marketing capture.
class PlaceholderFrame extends StatelessWidget {
  const PlaceholderFrame({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  static const _terracotta = Color(0xFFCC704B);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _terracotta, width: 1),
          ),
          child: child,
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _badge(label: title, color: _terracotta),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            color: _terracotta.withValues(alpha: 0.92),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Text(
              'PLACEHOLDER - replace before public launch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Pumps a placeholder representation of a screen at the requested
/// surface size and writes the rendered output to `screenshots/<name>`
/// (relative to repo root). Tagged tests that call this should pass
/// `--update-goldens` to (re)generate; without that flag the matcher
/// asserts and fails cleanly when the PNG is out of date.
Future<void> pumpAndCapture(
  WidgetTester tester, {
  required Size size,
  required String title,
  required String fileName,
  required Widget body,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PlaceholderFrame(title: title, child: body),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../screenshots/$fileName'),
  );
}
