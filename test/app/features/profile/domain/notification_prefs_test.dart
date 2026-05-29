import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';

void main() {
  group('NotificationPrefs.fromMap', () {
    test('returns defaults when map is null (no doc yet)', () {
      final prefs = NotificationPrefs.fromMap(null);

      expect(prefs.pushEnabled, isTrue);
      expect(prefs.urgentChat, isTrue);
      expect(prefs.taskUpdates, isTrue);
    });

    test('returns defaults when map is empty', () {
      final prefs = NotificationPrefs.fromMap(const {});

      expect(prefs.pushEnabled, isTrue);
      expect(prefs.urgentChat, isTrue);
      expect(prefs.taskUpdates, isTrue);
    });

    test('respects explicit false flags', () {
      final prefs = NotificationPrefs.fromMap(const {
        'pushEnabled': false,
        'urgentChat': false,
        'taskUpdates': false,
      });

      expect(prefs.pushEnabled, isFalse);
      expect(prefs.urgentChat, isFalse);
      expect(prefs.taskUpdates, isFalse);
    });

    test('ignores keys with wrong types instead of throwing', () {
      final prefs = NotificationPrefs.fromMap(const {
        'pushEnabled': 'yes', // bogus type — should fall back to default
        'urgentChat': 0,
        'taskUpdates': 'maybe',
      });

      expect(prefs.pushEnabled, isTrue);
      expect(prefs.urgentChat, isTrue);
      expect(prefs.taskUpdates, isTrue);
    });
  });

  group('NotificationPrefs.toMap', () {
    test('round-trips defaults', () {
      const prefs = NotificationPrefs();

      final map = prefs.toMap();

      expect(map, {
        'pushEnabled': true,
        'urgentChat': true,
        'taskUpdates': true,
      });
    });

    test('serialises non-defaults', () {
      const prefs = NotificationPrefs(
        pushEnabled: false,
        urgentChat: false,
        taskUpdates: false,
      );

      expect(prefs.toMap(), {
        'pushEnabled': false,
        'urgentChat': false,
        'taskUpdates': false,
      });
    });
  });

  group('NotificationPrefs.copyWith', () {
    test('replaces only specified fields', () {
      const prefs = NotificationPrefs();

      final next = prefs.copyWith(urgentChat: false);

      expect(next.pushEnabled, isTrue);
      expect(next.urgentChat, isFalse);
      expect(next.taskUpdates, isTrue);
    });

    test('copyWith taskUpdates leaves urgentChat untouched', () {
      const prefs = NotificationPrefs();

      final next = prefs.copyWith(taskUpdates: false);

      expect(next.urgentChat, isTrue);
      expect(next.taskUpdates, isFalse);
    });
  });
}
