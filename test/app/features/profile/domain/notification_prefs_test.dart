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
        'payments': true,
        'eventUpdates': true,
      });
    });

    test('serialises non-defaults', () {
      const prefs = NotificationPrefs(
        pushEnabled: false,
        urgentChat: false,
        taskUpdates: false,
        payments: false,
        eventUpdates: false,
      );

      expect(prefs.toMap(), {
        'pushEnabled': false,
        'urgentChat': false,
        'taskUpdates': false,
        'payments': false,
        'eventUpdates': false,
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

    test('copyWith payments leaves urgentChat + taskUpdates untouched', () {
      const prefs = NotificationPrefs();

      final next = prefs.copyWith(payments: false);

      expect(next.pushEnabled, isTrue);
      expect(next.urgentChat, isTrue);
      expect(next.taskUpdates, isTrue);
      expect(next.payments, isFalse);
    });
  });

  group('NotificationPrefs.payments round-trip', () {
    test('defaults to true (opt-in)', () {
      const prefs = NotificationPrefs();

      expect(prefs.payments, isTrue);
    });

    test('fromMap honours explicit false', () {
      final prefs = NotificationPrefs.fromMap(const {'payments': false});

      expect(prefs.payments, isFalse);
    });

    test('toMap serialises payments alongside other flags', () {
      const prefs = NotificationPrefs(payments: false);

      expect(prefs.toMap(), {
        'pushEnabled': true,
        'urgentChat': true,
        'taskUpdates': true,
        'payments': false,
        'eventUpdates': true,
      });
    });
  });

  group('NotificationPrefs.eventUpdates round-trip', () {
    test('defaults to true (opt-in)', () {
      const prefs = NotificationPrefs();

      expect(prefs.eventUpdates, isTrue);
    });

    test('fromMap honours explicit false', () {
      final prefs = NotificationPrefs.fromMap(const {'eventUpdates': false});

      expect(prefs.eventUpdates, isFalse);
    });

    test('copyWith eventUpdates leaves other flags untouched', () {
      const prefs = NotificationPrefs();

      final next = prefs.copyWith(eventUpdates: false);

      expect(next.pushEnabled, isTrue);
      expect(next.urgentChat, isTrue);
      expect(next.taskUpdates, isTrue);
      expect(next.payments, isTrue);
      expect(next.eventUpdates, isFalse);
    });
  });
}
