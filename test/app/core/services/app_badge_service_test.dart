import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/app_badge_service.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';

class _RecordingPlatform implements IAppBadgePlatform {
  final List<int> setCalls = [];
  int clearCalls = 0;

  @override
  Future<void> setBadgeCount(int count) async => setCalls.add(count);

  @override
  Future<void> clearBadge() async => clearCalls++;
}

void main() {
  late _RecordingPlatform platform;
  late FakeAppLifecycleSource lifecycle;
  late AppBadgeService service;

  setUp(() {
    platform = _RecordingPlatform();
    lifecycle = FakeAppLifecycleSource();
    service = AppBadgeService(platform: platform, lifecycleSource: lifecycle);
  });

  tearDown(() {
    service.dispose();
    lifecycle.dispose();
  });

  group('AppBadgeService.update', () {
    test(
      'update with positive total calls setBadgeCount with that total',
      () async {
        await service.update(5);

        expect(platform.setCalls, [5]);
        expect(platform.clearCalls, 0);
      },
    );

    test('update with zero clears the badge', () async {
      await service.update(0);

      expect(platform.setCalls, isEmpty);
      expect(platform.clearCalls, 1);
    });

    test('update with negative total clears the badge', () async {
      await service.update(-3);

      expect(platform.setCalls, isEmpty);
      expect(platform.clearCalls, 1);
    });

    test('successive updates pass through to setBadgeCount', () async {
      await service.update(1);
      await service.update(2);
      await service.update(3);

      expect(platform.setCalls, [1, 2, 3]);
    });
  });

  group('lifecycle re-application', () {
    test('resumed event re-applies the current total', () async {
      await service.update(7);
      platform.setCalls.clear();

      lifecycle.emit(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(platform.setCalls, [7]);
    });

    test('resumed event clears when current total is zero', () async {
      // Start at zero — initial total is 0 in the service.
      lifecycle.emit(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(platform.setCalls, isEmpty);
      expect(platform.clearCalls, 1);
    });

    test('non-resumed lifecycle events are ignored', () async {
      await service.update(4);
      platform.setCalls.clear();
      platform.clearCalls = 0;

      lifecycle.emit(AppLifecycleState.paused);
      lifecycle.emit(AppLifecycleState.inactive);
      lifecycle.emit(AppLifecycleState.detached);
      await Future<void>.delayed(Duration.zero);

      expect(platform.setCalls, isEmpty);
      expect(platform.clearCalls, 0);
    });
  });

  group('dispose', () {
    test('cancels the lifecycle subscription', () async {
      service.dispose();
      lifecycle.emit(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(platform.setCalls, isEmpty);
      expect(platform.clearCalls, 0);
    });
  });

  group('NoOpAppBadgePlatform', () {
    test('setBadgeCount + clearBadge complete without throwing', () async {
      const platform = NoOpAppBadgePlatform();

      await platform.setBadgeCount(5);
      await platform.clearBadge();
      // No assertion needed — completion is the contract.
    });
  });
}
