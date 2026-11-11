import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/services/qr_renderer.dart';

/// Stands in for the QR painter: a box keyed by what it would encode, so
/// tests check the link without decoding an image.
class FakeQrRenderer implements IQrRenderer {
  final rendered = <String>[];

  @override
  Widget render(
    String data, {
    required double size,
    required Color foreground,
    required Color background,
    required String semanticLabel,
  }) {
    rendered.add(data);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox.square(key: Key('qr:$data'), dimension: size),
    );
  }
}
