@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_screenshot_helpers.dart';

void main() {
  testWidgets('Dashboard placeholder — iPhone (375x812)', (tester) async {
    await pumpAndCapture(
      tester,
      size: const Size(375, 812),
      title: 'Dashboard',
      fileName: 'dashboard-mobile.png',
      body: _placeholderBody(),
    );
  });

  testWidgets('Dashboard placeholder — desktop (1280x800)', (tester) async {
    await pumpAndCapture(
      tester,
      size: const Size(1280, 800),
      title: 'Dashboard',
      fileName: 'dashboard-desktop.png',
      body: _placeholderBody(),
    );
  });
}

Widget _placeholderBody() {
  return Container(
    color: const Color(0xFFEADDCE),
    alignment: Alignment.center,
    child: const Text(
      'Dashboard',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D3436),
      ),
    ),
  );
}
