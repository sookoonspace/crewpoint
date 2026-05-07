import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart'
    show mimeTypeFor;

void main() {
  group('mimeTypeFor', () {
    test('maps .jpg extension to image/jpeg', () {
      expect(mimeTypeFor('photo.jpg'), equals('image/jpeg'));
    });

    test('maps .jpeg extension to image/jpeg', () {
      expect(mimeTypeFor('vacation.jpeg'), equals('image/jpeg'));
    });

    test('maps .PNG (case-insensitive) to image/png', () {
      expect(mimeTypeFor('photo.PNG'), equals('image/png'));
    });

    test('falls back to image/jpeg for unknown extension', () {
      expect(mimeTypeFor('weird.xyz'), equals('image/jpeg'));
    });

    test('falls back to image/jpeg for empty / extensionless input', () {
      expect(mimeTypeFor(''), equals('image/jpeg'));
      expect(mimeTypeFor('noext'), equals('image/jpeg'));
    });
  });
}
