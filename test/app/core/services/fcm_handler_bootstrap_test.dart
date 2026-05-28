import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/fcm_handler.dart';
import 'package:crewpoint_app/app/core/services/fcm_handler_bootstrap.dart';

RemoteMessage _msg({
  String? title,
  String? body,
  Map<String, String> data = const {},
}) {
  return RemoteMessage(
    notification: (title == null && body == null)
        ? null
        : RemoteNotification(title: title, body: body),
    data: data,
  );
}

void main() {
  group('FcmHandlerBootstrap', () {
    late StreamController<RemoteMessage> onMessageController;
    late StreamController<RemoteMessage> onOpenedController;
    late List<({String title, String body, String deepLink})> banners;
    late List<String> taps;
    late FcmHandler handler;

    setUp(() {
      onMessageController = StreamController<RemoteMessage>.broadcast();
      onOpenedController = StreamController<RemoteMessage>.broadcast();
      banners = [];
      taps = [];
      handler = FcmHandler(
        currentRoute: () => '/dashboard',
        showBanner: ({required title, required body, required deepLink}) {
          banners.add((title: title, body: body, deepLink: deepLink));
        },
        navigateTo: taps.add,
      );
    });

    tearDown(() async {
      await onMessageController.close();
      await onOpenedController.close();
    });

    test('onMessage event invokes handler.handleForegroundMessage', () async {
      final bootstrap = FcmHandlerBootstrap(
        handler: handler,
        onMessage: onMessageController.stream,
        onMessageOpenedApp: onOpenedController.stream,
        getInitialMessage: () async => null,
      );
      await bootstrap.start();

      onMessageController.add(
        _msg(
          title: '🚨 Urgent in Trip',
          body: 'msg',
          data: const {
            'eventId': 'evt-1',
            'deepLink': '/dashboard/event/evt-1/chat',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(banners, hasLength(1));
      expect(banners.first.title, '🚨 Urgent in Trip');
      expect(banners.first.deepLink, '/dashboard/event/evt-1/chat');

      await bootstrap.dispose();
    });

    test('onMessageOpenedApp event invokes handler.handleTap', () async {
      final bootstrap = FcmHandlerBootstrap(
        handler: handler,
        onMessage: onMessageController.stream,
        onMessageOpenedApp: onOpenedController.stream,
        getInitialMessage: () async => null,
      );
      await bootstrap.start();

      onOpenedController.add(
        _msg(data: const {'deepLink': '/dashboard/event/evt-1/chat'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(taps, ['/dashboard/event/evt-1/chat']);

      await bootstrap.dispose();
    });

    test('cold-start initialMessage is dispatched exactly once', () async {
      final bootstrap = FcmHandlerBootstrap(
        handler: handler,
        onMessage: onMessageController.stream,
        onMessageOpenedApp: onOpenedController.stream,
        getInitialMessage: () async =>
            _msg(data: const {'deepLink': '/dashboard/event/evt-cold/chat'}),
      );
      await bootstrap.start();

      expect(taps, ['/dashboard/event/evt-cold/chat']);

      await bootstrap.dispose();
    });

    test('null initialMessage does not navigate', () async {
      final bootstrap = FcmHandlerBootstrap(
        handler: handler,
        onMessage: onMessageController.stream,
        onMessageOpenedApp: onOpenedController.stream,
        getInitialMessage: () async => null,
      );
      await bootstrap.start();

      expect(taps, isEmpty);
      expect(banners, isEmpty);

      await bootstrap.dispose();
    });

    test('dispose cancels both stream subscriptions', () async {
      final bootstrap = FcmHandlerBootstrap(
        handler: handler,
        onMessage: onMessageController.stream,
        onMessageOpenedApp: onOpenedController.stream,
        getInitialMessage: () async => null,
      );
      await bootstrap.start();
      await bootstrap.dispose();

      onMessageController.add(
        _msg(title: 't', body: 'b', data: const {'deepLink': '/x'}),
      );
      onOpenedController.add(_msg(data: const {'deepLink': '/y'}));
      await Future<void>.delayed(Duration.zero);

      expect(banners, isEmpty);
      expect(taps, isEmpty);
    });
  });
}
