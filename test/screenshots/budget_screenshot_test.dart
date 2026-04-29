@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_screenshot_helpers.dart';

void main() {
  testWidgets('Budget placeholder — iPhone (375x812)', (tester) async {
    await pumpAndCapture(
      tester,
      size: const Size(375, 812),
      title: 'Budget',
      fileName: 'budget-mobile.png',
      body: _placeholderBody(),
    );
  });

  testWidgets('Budget placeholder — desktop (1280x800)', (tester) async {
    await pumpAndCapture(
      tester,
      size: const Size(1280, 800),
      title: 'Budget',
      fileName: 'budget-desktop.png',
      body: _placeholderBody(),
    );
  });
}

Widget _placeholderBody() {
  return Container(
    color: const Color(0xFFEADDCE),
    alignment: Alignment.center,
    child: const Text(
      'Budget',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF6B9080),
      ),
    ),
  );
}
