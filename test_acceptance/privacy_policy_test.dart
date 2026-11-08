import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Req 39 (#74): the privacy policy covers children and Canada. Z-01 and
/// Z-04 also need the participant and deletion work in later items, so they
/// are not on the finished list yet. A lawyer must approve this policy
/// before prod (`ai_specs/todo.md`).
void main() {
  final source = File('docs/legal/privacy-policy.md').readAsStringSync();
  final bundled = File('assets/legal/privacy-policy.md').readAsStringSync();
  final hosted = File('web/legal/privacy.html').readAsStringSync();
  final policy = source.toLowerCase();

  String section(String heading) {
    final start = source.indexOf('\n## $heading');
    expect(start, isNonNegative, reason: 'missing "## $heading"');
    final next = source.indexOf('\n## ', start + 1);
    return source.substring(start, next < 0 ? null : next).toLowerCase();
  }

  test('the app and the hosted page carry the same policy', () {
    expect(bundled, source);
    expect(hosted, contains('Canada'));
    expect(hosted, contains('parent or guardian'));
  });

  group('Z-01 children', () {
    test('Z-01 children have no account, and only a parent, guardian or '
        'permitted organizer enters their details', () {
      final children = section('Children');
      expect(children, contains('do not have'));
      expect(children, contains('parent or guardian'));
      expect(children, contains('organizer'));
      expect(children, isNot(contains('we do not knowingly collect data')));
    });

    test('Z-01 birth dates and private details are limited, and reports '
        'show age bands', () {
      final children = section('Children');
      expect(children, contains('birth date'));
      expect(children, contains('age band'));
      expect(children, contains('permission'));
    });

    test('Z-01 a parent can see, correct or delete a child\'s details, and '
        'they go with the parent\'s account', () {
      final children = section('Children');
      expect(children, contains('correct'));
      expect(children, contains('delete'));
      expect(children, contains('another linked adult'));
    });
  });

  group('Z-04 UK and Canadian attendees', () {
    test('Z-04 Canadian rights, the regulator and cross-border storage', () {
      final canada = section('Your rights').split('### under canadian')[1];
      expect(canada, contains('pipeda'));
      expect(canada, contains('quebec'));
      expect(canada, contains('withdraw'));
      expect(canada, contains('privacy commissioner of canada'));
      expect(canada, contains('united states'));
    });

    test('Z-04 UK attendees have a regulator to contact', () {
      expect(policy, contains('uk gdpr'));
      expect(policy, contains("information commissioner's office"));
    });

    test('Z-04 deletion describes what happens today', () {
      final deletion = section('Account deletion');
      expect(deletion, contains('anonymous id'));
      expect(deletion, contains('co-owner'));
      expect(deletion, isNot(contains('deleted_user')));
    });
  });

  test('payment handles are visible only to people who share an event', () {
    expect(policy, contains('share an event'));
  });
}
