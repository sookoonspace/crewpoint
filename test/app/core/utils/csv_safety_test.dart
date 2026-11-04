import 'package:crewpoint_app/app/core/utils/csv_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('neutraliseCsvCell', () {
    for (final (name, lead) in [
      ('equals', '='),
      ('plus', '+'),
      ('minus', '-'),
      ('at', '@'),
      ('tab', '\t'),
      ('carriage return', '\r'),
    ]) {
      test('neutralises a cell starting with $name', () {
        final cell = '${lead}SUM(A1)';
        expect(neutraliseCsvCell(cell), "'$cell");
      });
    }

    test('leaves other cells alone', () {
      for (final cell in [
        '',
        'Dinner',
        '12.50',
        'a=b',
        'x-y',
        'me@test',
        ' =x',
      ]) {
        expect(neutraliseCsvCell(cell), cell);
      }
    });

    test('is not applied twice', () {
      expect(neutraliseCsvCell(neutraliseCsvCell('=1')), "'=1");
    });
  });
}
