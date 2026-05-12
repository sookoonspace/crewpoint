import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_currency_field.dart';

void main() {
  testWidgets('parses en_US input + renders currency symbol prefix', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppCurrencyField(
              controller: controller,
              currencyCode: 'USD',
              labelText: 'Amount',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Amount'), findsOneWidget);
    // Default Material renders the prefixText alongside the field; symbol = "$".
    expect(find.textContaining(r'$'), findsWidgets);

    controller.text = '1234.56';
    expect(formKey.currentState!.validate(), isTrue);

    controller.dispose();
  });

  testWidgets('rejects negative + 3-decimal input', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppCurrencyField(
              controller: controller,
              currencyCode: 'USD',
            ),
          ),
        ),
      ),
    );

    controller.text = '-1';
    expect(formKey.currentState!.validate(), isFalse);

    controller.text = '1.234';
    expect(formKey.currentState!.validate(), isFalse);

    controller.text = '';
    expect(formKey.currentState!.validate(), isTrue);

    controller.dispose();
  });

  // The widget-level "no Localizations" path is impossible to construct in
  // a widget test — TextField requires MaterialLocalizations. The
  // production fallback (`Localizations.maybeLocaleOf(context) ?? 'en_US'`)
  // is exercised at the pure-parser level below; the widget defensively
  // passes that fallback to NumberFormat, so non-MaterialApp shells get
  // sane behaviour even though we can't pump such a tree here.
  group('parseCurrencyInput (locale-aware pure parser)', () {
    test('en_US parses positive + zero + 2-decimal values', () {
      expect(parseCurrencyInput('0', locale: 'en_US'), 0.0);
      expect(parseCurrencyInput('12', locale: 'en_US'), 12.0);
      expect(parseCurrencyInput('1234.56', locale: 'en_US'), 1234.56);
    });

    test('empty / whitespace returns null', () {
      expect(parseCurrencyInput('', locale: 'en_US'), isNull);
      expect(parseCurrencyInput('   ', locale: 'en_US'), isNull);
    });

    test('en_US rejects negative + non-numeric + 3-decimal', () {
      expect(
        () => parseCurrencyInput('-1', locale: 'en_US'),
        throwsFormatException,
      );
      expect(
        () => parseCurrencyInput('abc', locale: 'en_US'),
        throwsFormatException,
      );
      expect(
        () => parseCurrencyInput('1.234', locale: 'en_US'),
        throwsFormatException,
      );
    });

    test('de_DE accepts comma decimal; rejects 3-decimal comma', () {
      expect(parseCurrencyInput('0,5', locale: 'de_DE'), 0.5);
      expect(parseCurrencyInput('1234,56', locale: 'de_DE'), 1234.56);
      expect(
        () => parseCurrencyInput('1,234', locale: 'de_DE'),
        throwsFormatException,
      );
    });
  });
}
