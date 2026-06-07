import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/fcm_handler.dart';

void main() {
  group('FcmHandler.handleForegroundMessage', () {
    test('shows banner when not on the relevant chat route', () {
      String? bannerTitle;
      String? bannerDeepLink;
      final handler = FcmHandler(
        currentRoute: () => '/dashboard',
        showBanner: ({required title, required body, required deepLink}) {
          bannerTitle = title;
          bannerDeepLink = deepLink;
        },
        navigateTo: (_) {},
      );

      final suppressed = handler.handleForegroundMessage(
        title: '🚨 Urgent in Trip',
        body: 'Bear at the campsite',
        data: const {
          'eventId': 'evt-1',
          'deepLink': '/dashboard/event/evt-1/chat',
        },
      );

      expect(suppressed, isFalse);
      expect(bannerTitle, '🚨 Urgent in Trip');
      expect(bannerDeepLink, '/dashboard/event/evt-1/chat');
    });

    test('suppresses banner when already on this event\'s chat', () {
      var bannerCount = 0;
      final handler = FcmHandler(
        currentRoute: () => '/dashboard/event/evt-1/chat',
        showBanner: ({required title, required body, required deepLink}) {
          bannerCount++;
        },
        navigateTo: (_) {},
      );

      final suppressed = handler.handleForegroundMessage(
        title: '🚨 Urgent in Trip',
        body: 'msg',
        data: const {
          'eventId': 'evt-1',
          'deepLink': '/dashboard/event/evt-1/chat',
        },
      );

      expect(suppressed, isTrue);
      expect(bannerCount, 0);
    });

    test('still shows banner when on chat for a DIFFERENT event', () {
      var bannerCount = 0;
      final handler = FcmHandler(
        currentRoute: () => '/dashboard/event/evt-2/chat',
        showBanner: ({required title, required body, required deepLink}) {
          bannerCount++;
        },
        navigateTo: (_) {},
      );

      final suppressed = handler.handleForegroundMessage(
        title: '🚨 Urgent in Trip',
        body: 'msg',
        data: const {
          'eventId': 'evt-1',
          'deepLink': '/dashboard/event/evt-1/chat',
        },
      );

      expect(suppressed, isFalse);
      expect(bannerCount, 1);
    });
  });

  group('FcmHandler.handleTap', () {
    test('navigates when data carries a deepLink', () {
      String? navigated;
      final handler = FcmHandler(
        currentRoute: () => null,
        showBanner: ({required title, required body, required deepLink}) {},
        navigateTo: (link) => navigated = link,
      );

      handler.handleTap(
        data: const {'deepLink': '/dashboard/event/evt-1/chat'},
      );

      expect(navigated, '/dashboard/event/evt-1/chat');
    });

    test('no-op when deepLink is missing', () {
      var navigateCount = 0;
      final handler = FcmHandler(
        currentRoute: () => null,
        showBanner: ({required title, required body, required deepLink}) {},
        navigateTo: (_) => navigateCount++,
      );

      handler.handleTap(data: const {});

      expect(navigateCount, 0);
    });
  });

  group('FcmHandler.handleAction', () {
    test('mark_done action dispatches markTaskDone with eventId + taskId', () {
      String? doneEventId;
      String? doneTaskId;
      final handler = FcmHandler(
        currentRoute: () => null,
        showBanner: ({required title, required body, required deepLink}) {},
        navigateTo: (_) {},
        markTaskDone: ({required eventId, required taskId}) {
          doneEventId = eventId;
          doneTaskId = taskId;
        },
      );

      handler.handleAction(
        data: const {
          'action': 'mark_done',
          'eventId': 'evt-1',
          'taskId': 't-99',
        },
      );

      expect(doneEventId, 'evt-1');
      expect(doneTaskId, 't-99');
    });

    test('ignores unknown action identifiers', () {
      var doneCalls = 0;
      final handler = FcmHandler(
        currentRoute: () => null,
        showBanner: ({required title, required body, required deepLink}) {},
        navigateTo: (_) {},
        markTaskDone: ({required eventId, required taskId}) => doneCalls++,
      );

      handler.handleAction(
        data: const {'action': 'snooze', 'eventId': 'evt-1', 'taskId': 't-99'},
      );

      expect(doneCalls, 0);
    });

    test('mark_done no-op when eventId or taskId is missing', () {
      var doneCalls = 0;
      final handler = FcmHandler(
        currentRoute: () => null,
        showBanner: ({required title, required body, required deepLink}) {},
        navigateTo: (_) {},
        markTaskDone: ({required eventId, required taskId}) => doneCalls++,
      );

      handler.handleAction(
        data: const {'action': 'mark_done', 'eventId': 'evt-1'},
      );
      handler.handleAction(
        data: const {'action': 'mark_done', 'taskId': 't-99'},
      );

      expect(doneCalls, 0);
    });

    test('mute_event action dispatches muteEvent with the carrier eventId', () {
      String? mutedEventId;
      Duration? mutedFor;
      final handler = FcmHandler(
        currentRoute: () => null,
        showBanner: ({required title, required body, required deepLink}) {},
        navigateTo: (_) {},
        muteEvent: ({required eventId, required duration}) {
          mutedEventId = eventId;
          mutedFor = duration;
        },
      );

      handler.handleAction(
        data: const {'action': 'mute_event', 'eventId': 'evt-9'},
      );

      expect(mutedEventId, 'evt-9');
      // Default mute-from-notification duration is 8 hours — matches the
      // 8h preset on MuteEventSheet so the user gets the same window
      // whether they tap the notification action or open the app.
      expect(mutedFor, const Duration(hours: 8));
    });

    test('mute_event no-op when eventId missing', () {
      var muteCalls = 0;
      final handler = FcmHandler(
        currentRoute: () => null,
        showBanner: ({required title, required body, required deepLink}) {},
        navigateTo: (_) {},
        muteEvent: ({required eventId, required duration}) => muteCalls++,
      );

      handler.handleAction(data: const {'action': 'mute_event'});

      expect(muteCalls, 0);
    });
  });
}
