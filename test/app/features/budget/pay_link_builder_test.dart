import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/data/pay_link_builder.dart';

void main() {
  group('PayLinkBuilder.venmo', () {
    test('builds the venmo:// deep link with required params', () {
      final uri = PayLinkBuilder.venmo(
        handle: 'alex_codes',
        amount: 25,
        note: 'Trip settle',
      );
      expect(uri.scheme, equals('venmo'));
      expect(uri.host, equals('paycharge'));
      expect(uri.queryParameters['txn'], equals('pay'));
      expect(uri.queryParameters['recipients'], equals('alex_codes'));
      expect(uri.queryParameters['amount'], equals('25.00'));
      expect(uri.queryParameters['note'], equals('Trip settle'));
    });

    test('amount is always 2 dp', () {
      final uri = PayLinkBuilder.venmo(handle: 'a', amount: 25.5, note: 'x');
      expect(uri.queryParameters['amount'], equals('25.50'));
    });

    test('throws on invalid handle', () {
      expect(
        () => PayLinkBuilder.venmo(handle: 'has space', amount: 1, note: 'x'),
        throwsArgumentError,
      );
      expect(
        () => PayLinkBuilder.venmo(handle: '', amount: 1, note: 'x'),
        throwsArgumentError,
      );
    });

    test('note longer than 60 chars is truncated', () {
      final long = 'x' * 80;
      final uri = PayLinkBuilder.venmo(handle: 'a', amount: 1, note: long);
      expect((uri.queryParameters['note'] ?? '').length, lessThanOrEqualTo(60));
    });

    test('webFallback returns https://venmo.com/{handle}?...', () {
      final uri = PayLinkBuilder.venmoWebFallback(
        handle: 'alex',
        amount: 12.5,
        note: 'lunch',
      );
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('venmo.com'));
      expect(uri.path, equals('/alex'));
      expect(uri.queryParameters['txn'], equals('pay'));
      expect(uri.queryParameters['amount'], equals('12.50'));
    });
  });

  group('PayLinkBuilder.cashApp', () {
    test('builds the https://cash.app/\$handle/amount link', () {
      final uri = PayLinkBuilder.cashApp(handle: 'alex', amount: 12.34);
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('cash.app'));
      expect(uri.path, equals('/\$alex/12.34'));
    });

    test('throws on invalid handle', () {
      expect(
        () => PayLinkBuilder.cashApp(handle: 'has space', amount: 1),
        throwsArgumentError,
      );
    });
  });
}
