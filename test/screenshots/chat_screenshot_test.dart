@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_screenshot_helpers.dart';

void main() {
  testWidgets('Chat placeholder — iPhone (375x812)', (tester) async {
    await pumpAndCapture(
      tester,
      size: const Size(375, 812),
      title: 'Chat',
      fileName: 'chat-mobile.png',
      body: _placeholderBody(),
    );
  });

  testWidgets('Chat placeholder — desktop (1280x800)', (tester) async {
    await pumpAndCapture(
      tester,
      size: const Size(1280, 800),
      title: 'Chat',
      fileName: 'chat-desktop.png',
      body: _placeholderBody(),
    );
  });
}

Widget _placeholderBody() {
  return Container(
    color: const Color(0xFFEADDCE),
    alignment: Alignment.center,
    child: const Text(
      'Chat',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Color(0xFFCC704B),
      ),
    ),
  );
}
