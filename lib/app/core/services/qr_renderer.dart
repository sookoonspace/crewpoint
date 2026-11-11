import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Draws a QR code (Req 47). A seam, so tests check what is encoded without
/// painting one.
abstract interface class IQrRenderer {
  Widget render(
    String data, {
    required double size,
    required Color foreground,
    required Color background,
    required String semanticLabel,
  });
}

class QrFlutterRenderer implements IQrRenderer {
  const QrFlutterRenderer();

  @override
  Widget render(
    String data, {
    required double size,
    required Color foreground,
    required Color background,
    required String semanticLabel,
  }) => Semantics(
    label: semanticLabel,
    image: true,
    child: QrImageView(
      data: data,
      size: size,
      backgroundColor: background,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: foreground),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: foreground,
      ),
    ),
  );
}
