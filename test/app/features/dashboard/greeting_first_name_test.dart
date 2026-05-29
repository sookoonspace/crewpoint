import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/greeting_first_name.dart';

void main() {
  test('returns "there" when displayName is null', () {
    expect(greetingFirstName(null), 'there');
  });

  test('returns "there" when displayName is empty or whitespace', () {
    expect(greetingFirstName(''), 'there');
    expect(greetingFirstName('   '), 'there');
  });

  test('returns the only token for a single-word displayName', () {
    expect(greetingFirstName('Alex'), 'Alex');
  });

  test('returns first token for a multi-word displayName', () {
    expect(greetingFirstName('Alex Morgan'), 'Alex');
    expect(greetingFirstName('Alex  Morgan'), 'Alex');
  });

  test('trims leading whitespace before splitting', () {
    expect(greetingFirstName('  Alex Morgan'), 'Alex');
  });
}
