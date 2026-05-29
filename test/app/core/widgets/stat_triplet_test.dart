import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/stat_triplet.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('renders three cells with values and labels', (tester) async {
    await pump(
      tester,
      const StatTriplet(
        cells: [
          StatCell(value: '4', label: 'Events'),
          StatCell(value: '12', label: 'Tasks'),
          StatCell(value: r'$150', label: 'Owed'),
        ],
      ),
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text(r'$150'), findsOneWidget);
    expect(find.text('Owed'), findsOneWidget);
  });

  testWidgets('renders "—" placeholder when a cell value is null', (
    tester,
  ) async {
    await pump(
      tester,
      const StatTriplet(
        cells: [
          StatCell(value: '4', label: 'Events'),
          StatCell(value: null, label: 'Tasks'),
          StatCell(value: null, label: 'Owed'),
        ],
      ),
    );
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Owed'), findsOneWidget);
  });
}
