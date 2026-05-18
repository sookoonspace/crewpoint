import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/screen_header.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SafeArea(child: child)),
      ),
    );
  }

  testWidgets('renders title and optional subtitle', (tester) async {
    await pump(
      tester,
      const ScreenHeader(title: 'Tasks', subtitle: 'Wednesday, Dec 11'),
    );
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Wednesday, Dec 11'), findsOneWidget);
  });

  testWidgets('renders trailing actions when provided', (tester) async {
    await pump(
      tester,
      ScreenHeader(
        title: 'Home',
        actions: [
          IconButton(
            key: const Key('header.action.join'),
            icon: const Icon(Icons.login),
            onPressed: () {},
          ),
        ],
      ),
    );
    expect(find.byKey(const Key('header.action.join')), findsOneWidget);
  });
}
