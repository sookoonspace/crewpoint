import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/main.dart';

void main() {
  testWidgets('App renders CrewPoint text', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('CrewPoint'), findsOneWidget);
  });
}
