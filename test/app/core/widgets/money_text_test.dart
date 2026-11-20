import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('formats USD amount with the currency code', (tester) async {
    await pump(tester, const MoneyText(amount: 150.0, currencyCode: 'USD'));
    expect(find.text(r'$150.00'), findsOneWidget);
  });

  testWidgets('uses tabular digits', (tester) async {
    await pump(tester, const MoneyText(amount: 80.0, currencyCode: 'USD'));
    final widget = tester.widget<Text>(find.text(r'$80.00'));
    expect(
      widget.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('renders "\$—" when currencyCode is empty', (tester) async {
    await pump(tester, const MoneyText(amount: 12.5, currencyCode: ''));
    expect(find.text(r'$—'), findsOneWidget);
  });
}
