// The design guard (Spec #186 Req 16, ledger L18): outside
// lib/app/core/design/, code takes colours, fonts, sizes and visual widgets
// from the design system, never its own.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'design_guard.dart';

void main() {
  group('findStyleHits', () {
    List<String> rules(String source) => [
      for (final hit in findStyleHits('a.dart', source)) hit.rule,
    ];

    test('flags raw colours and Material colour names', () {
      expect(rules('final c = Color(0xFF112233);'), ['Color(0x…)']);
      expect(rules('final c = Colors.white;'), ['Colors.…']);
      expect(rules('final c = context.cp.colors.accent;'), isEmpty);
    });

    test('flags font families set outside the design system', () {
      expect(rules('final s = GoogleFonts.inter();'), ['GoogleFonts']);
      expect(rules("const s = TextStyle(fontFamily: 'Mono');"), [
        'fontFamily:',
      ]);
    });

    test('flags bare non-zero numbers in sizes, spacing and radii', () {
      expect(rules('const EdgeInsets.all(16)'), ['number in EdgeInsets']);
      expect(rules('EdgeInsets.fromLTRB(0, 8, 0, 0)'), [
        'number in EdgeInsets',
      ]);
      expect(rules('const SizedBox(height: 8)'), ['number in SizedBox']);
      expect(rules('BorderRadius.circular(12)'), ['number in BorderRadius']);
      expect(rules('Radius.circular(4.5)'), ['number in Radius']);
    });

    test('allows zero, tokens and calculated sizes', () {
      expect(rules('const SizedBox(height: 0)'), isEmpty);
      expect(rules('EdgeInsets.all(space.lg)'), isEmpty);
      expect(rules('SizedBox(width: maxWidth * 0.5)'), isEmpty);
      expect(rules('EdgeInsets.only(top: inset + 2)'), isEmpty);
    });

    test('flags plain Material visual widgets', () {
      expect(rules('Card(child: x)'), ['Card']);
      expect(rules('ListTile(title: x)'), ['ListTile']);
      expect(rules('TextButton.icon(onPressed: f)'), ['TextButton']);
      expect(rules('FilledButton(onPressed: f)'), ['FilledButton']);
      expect(rules('ChoiceChip(label: x)'), ['ChoiceChip']);
    });

    test('leaves out style helpers, lookalike names, comments and strings', () {
      expect(rules('ElevatedButton.styleFrom(elevation: e)'), isEmpty);
      expect(rules('ActionChip(label: x)'), isEmpty);
      expect(rules('MyCard(child: x)'), isEmpty);
      expect(rules('// Colors.red and Card(child)'), isEmpty);
      expect(rules("final s = 'Colors.red Card(';"), isEmpty);
      expect(rules('/* SizedBox(height: 8) */'), isEmpty);
    });

    test('reports the line of each hit', () {
      final hits = findStyleHits('a.dart', 'a\nb\nfinal c = Colors.red;');
      expect(hits.single.line, 3);
    });
  });

  test('code outside the design system uses only design tokens', () {
    final offenders = [
      for (final file in guardedFiles())
        if (!listedExceptions.containsKey(file.path))
          for (final hit in findStyleHits(file.path, file.readAsStringSync()))
            hit.toString(),
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'Use the tokens and components in lib/app/core/design/ instead.',
    );
  });

  test('every listed exception still exists', () {
    expect([
      for (final path in listedExceptions.keys)
        if (!File(path).existsSync()) path,
    ], isEmpty);
  });
}
