import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';

void main() {
  test('returns the mapped name when the uid is present', () {
    expect(
      resolveMemberName(uid: 'u1', memberNames: {'u1': 'Alice'}),
      equals('Alice'),
    );
  });

  test(
    'returns "(no longer in event)" when the uid is missing from the map',
    () {
      expect(
        resolveMemberName(uid: 'u-removed', memberNames: const {}),
        equals('(no longer in event)'),
      );
    },
  );

  test('returns "(no longer in event)" when uid is null', () {
    expect(
      resolveMemberName(uid: null, memberNames: {'u1': 'Alice'}),
      equals('(no longer in event)'),
    );
  });

  test('treats an empty mapped name as missing', () {
    expect(
      resolveMemberName(uid: 'u1', memberNames: const {'u1': ''}),
      equals('(no longer in event)'),
    );
  });
}
