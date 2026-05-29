import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
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

  testWidgets('owedToYou variant uses sageDark color', (tester) async {
    await pump(
      tester,
      const MoneyText(
        amount: 80.0,
        currencyCode: 'USD',
        sign: MoneySign.owedToYou,
      ),
    );
    final widget = tester.widget<Text>(find.text(r'$80.00'));
    expect(widget.style?.color, AppColors.moneyOwedToYouFg);
  });

  testWidgets('youOwe variant uses terracottaDark color', (tester) async {
    await pump(
      tester,
      const MoneyText(
        amount: 45.0,
        currencyCode: 'USD',
        sign: MoneySign.youOwe,
      ),
    );
    final widget = tester.widget<Text>(find.text(r'$45.00'));
    expect(widget.style?.color, AppColors.moneyYouOweFg);
  });

  testWidgets('renders "\$—" when currencyCode is empty', (tester) async {
    await pump(tester, const MoneyText(amount: 12.5, currencyCode: ''));
    expect(find.text(r'$—'), findsOneWidget);
  });
}
