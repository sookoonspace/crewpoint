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
        'dailyDigest': false,
      });
    });

    test('serialises non-defaults', () {
      const prefs = NotificationPrefs(
        pushEnabled: false,
        urgentChat: false,
        taskUpdates: false,
        payments: false,
        eventUpdates: false,
        dailyDigest: true,
      );

      expect(prefs.toMap(), {
        'pushEnabled': false,
        'urgentChat': false,
        'taskUpdates': false,
        'payments': false,
        'eventUpdates': false,
        'dailyDigest': true,
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
        'dailyDigest': false,
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

  group('NotificationPrefs.fromMap ignores withdrawn fields', () {
    test('legacy criticalOptIn=true is silently dropped', () {
      // Phase 4 critical-alert opt-in withdrawn for V1/V2. Existing
      // Firestore docs that still carry this field must not throw or
      // surface it back through the model.
      final prefs = NotificationPrefs.fromMap(const {
        'criticalOptIn': true,
        'pushEnabled': true,
      });

      expect(prefs.toMap().containsKey('criticalOptIn'), isFalse);
    });
  });

  group('NotificationPrefs quiet hours (Phase 5)', () {
    test(
      'defaults: all three fields null → quiet hours OFF (CF skips check)',
      () {
        const prefs = NotificationPrefs();

        expect(prefs.quietHoursStart, isNull);
        expect(prefs.quietHoursEnd, isNull);
        expect(prefs.timezone, isNull);
      },
    );

    test('fromMap reads minutes-of-day ints + IANA timezone string', () {
      final prefs = NotificationPrefs.fromMap(const {
        'quietHoursStart': 22 * 60, // 22:00
        'quietHoursEnd': 7 * 60, // 07:00 (crosses midnight)
        'timezone': 'America/New_York',
      });

      expect(prefs.quietHoursStart, 22 * 60);
      expect(prefs.quietHoursEnd, 7 * 60);
      expect(prefs.timezone, 'America/New_York');
    });

    test('fromMap drops wrong types instead of throwing', () {
      final prefs = NotificationPrefs.fromMap(const {
        'quietHoursStart': '22:00', // string instead of int
        'quietHoursEnd': true,
        'timezone': 42,
      });

      expect(prefs.quietHoursStart, isNull);
      expect(prefs.quietHoursEnd, isNull);
      expect(prefs.timezone, isNull);
    });

    test(
      'toMap omits quiet-hour fields when null (Firestore stays sparse)',
      () {
        const prefs = NotificationPrefs();

        // The CF only checks quiet hours when all three are present, so
        // omitting them is cheaper + clearer than writing `null` keys.
        expect(prefs.toMap().containsKey('quietHoursStart'), isFalse);
        expect(prefs.toMap().containsKey('quietHoursEnd'), isFalse);
        expect(prefs.toMap().containsKey('timezone'), isFalse);
      },
    );

    test('toMap serialises quiet-hour fields when set', () {
      const prefs = NotificationPrefs(
        quietHoursStart: 22 * 60,
        quietHoursEnd: 7 * 60,
        timezone: 'America/New_York',
      );

      final map = prefs.toMap();
      expect(map['quietHoursStart'], 22 * 60);
      expect(map['quietHoursEnd'], 7 * 60);
      expect(map['timezone'], 'America/New_York');
    });

    test('copyWith sets quiet-hour fields without touching other flags', () {
      const prefs = NotificationPrefs();

      final next = prefs.copyWith(
        quietHoursStart: 22 * 60,
        quietHoursEnd: 7 * 60,
        timezone: 'UTC',
      );

      expect(next.quietHoursStart, 22 * 60);
      expect(next.quietHoursEnd, 7 * 60);
      expect(next.timezone, 'UTC');
      expect(next.pushEnabled, isTrue);
      expect(next.urgentChat, isTrue);
    });
  });

  group('NotificationPrefs.locale (Phase 6)', () {
    test('defaults to null → server falls back to English', () {
      const prefs = NotificationPrefs();

      expect(prefs.locale, isNull);
    });

    test('fromMap honours explicit non-empty string', () {
      final prefs = NotificationPrefs.fromMap(const {'locale': 'es-MX'});

      expect(prefs.locale, 'es-MX');
    });

    test('fromMap drops empty string + wrong types', () {
      expect(NotificationPrefs.fromMap(const {'locale': ''}).locale, isNull);
      expect(NotificationPrefs.fromMap(const {'locale': 42}).locale, isNull);
    });

    test('toMap omits locale when null (Firestore stays sparse)', () {
      const prefs = NotificationPrefs();

      expect(prefs.toMap().containsKey('locale'), isFalse);
    });

    test('toMap serialises locale when set', () {
      const prefs = NotificationPrefs(locale: 'es-MX');

      expect(prefs.toMap()['locale'], 'es-MX');
    });

    test('copyWith locale leaves other fields untouched', () {
      const prefs = NotificationPrefs();

      final next = prefs.copyWith(locale: 'fr');

      expect(next.locale, 'fr');
      expect(next.pushEnabled, isTrue);
      expect(next.urgentChat, isTrue);
    });
  });

  group('NotificationPrefs.dailyDigest (Phase 6.1)', () {
    test(
      'defaults to false — opt-in, no morning ping without explicit consent',
      () {
        const prefs = NotificationPrefs();

        expect(prefs.dailyDigest, isFalse);
      },
    );

    test('fromMap honours explicit true', () {
      final prefs = NotificationPrefs.fromMap(const {'dailyDigest': true});

      expect(prefs.dailyDigest, isTrue);
    });

    test('fromMap falls back to false on wrong type', () {
      final prefs = NotificationPrefs.fromMap(const {'dailyDigest': 'yes'});

      expect(prefs.dailyDigest, isFalse);
    });

    test('toMap serialises dailyDigest alongside other flags', () {
      const prefs = NotificationPrefs(dailyDigest: true);

      expect(prefs.toMap()['dailyDigest'], true);
    });

    test('copyWith dailyDigest leaves other flags untouched', () {
      const prefs = NotificationPrefs();

      final next = prefs.copyWith(dailyDigest: true);

      expect(next.dailyDigest, isTrue);
      expect(next.pushEnabled, isTrue);
      expect(next.locale, isNull);
    });
  });
}
