// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Generates DEV and STG badged icons from the base launcher icon.
/// Run: dart run scripts/generate_flavor_icons.dart
void main() {
  final baseFile = File('assets/icons/launcher_icon.png');
  if (!baseFile.existsSync()) {
    print('Error: assets/icons/launcher_icon.png not found');
    exit(1);
  }

  final baseBytes = baseFile.readAsBytesSync();

  // Generate DEV icon (orange badge)
  _generateBadgedIcon(
    baseBytes: baseBytes,
    label: 'DEV',
    badgeColor: img.ColorRgba8(230, 126, 34, 255), // Orange
    outputPath: 'assets/icons/launcher_icon_dev.png',
  );

  // Generate STG icon (blue badge)
  _generateBadgedIcon(
    baseBytes: baseBytes,
    label: 'STG',
    badgeColor: img.ColorRgba8(52, 152, 219, 255), // Blue
    outputPath: 'assets/icons/launcher_icon_stg.png',
  );

  print('Done! Generated launcher_icon_dev.png and launcher_icon_stg.png');
}

void _generateBadgedIcon({
  required Uint8List baseBytes,
  required String label,
  required img.Color badgeColor,
  required String outputPath,
}) {
  final image = img.decodePng(baseBytes)!;
  final size = image.width; // 1024

  // Draw a banner/ribbon across the bottom-left corner
  final bannerHeight = (size * 0.18).toInt(); // ~184px on 1024
  final bannerY = size - bannerHeight;

  // Draw the banner background (bottom strip)
  img.fillRect(
    image,
    x1: 0,
    y1: bannerY,
    x2: size,
    y2: size,
    color: badgeColor,
  );

  // Draw text centered on the banner
  final textColor = img.ColorRgba8(255, 255, 255, 255);

  // Use built-in bitmap font (largest available)
  final font = img.arial48;

  // Calculate text position for centering
  // arial48 chars are ~24px wide, so scale by drawing multiple times won't work
  // Instead, draw large text by scaling a small image
  final textImage = img.Image(width: size, height: bannerHeight);
  img.fill(textImage, color: badgeColor);

  // Draw the label text centered
  const charWidth = 28; // approximate width per char in arial48
  final textWidth = label.length * charWidth;
  final textX = (size - textWidth) ~/ 2;
  final textY = (bannerHeight - 48) ~/ 2; // center vertically in banner

  img.drawString(
    textImage,
    label,
    font: font,
    x: textX,
    y: textY,
    color: textColor,
  );

  // Scale the text image up for better visibility
  final scaledText = img.copyResize(
    textImage,
    width: size,
    height: bannerHeight,
    interpolation: img.Interpolation.nearest,
  );

  // Composite the scaled text onto the main image
  img.compositeImage(image, scaledText, dstX: 0, dstY: bannerY);

  // Save
  final output = File(outputPath);
  output.writeAsBytesSync(img.encodePng(image));
  print('Generated $outputPath');
}
