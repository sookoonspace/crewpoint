import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/app_badge_service.dart';

/// Method channel name declared by `app_badge_plus`'s
/// `MethodChannelAppBadgePlus`. Pinning it here keeps the test honest
/// against the package's public contract — if the channel name changes
/// on a major upgrade, this test fails fast.
const _channel = MethodChannel('app_badge_plus');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('AppBadgePlusPlatform', () {
    test('setBadgeCount(N) invokes updateBadge on the platform channel '
        'with count=N', () async {
      const adapter = AppBadgePlusPlatform();

      await adapter.setBadgeCount(7);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'updateBadge');
      expect(calls.single.arguments, {'count': 7});
    });

    test('clearBadge() invokes updateBadge with count=0', () async {
      const adapter = AppBadgePlusPlatform();

      await adapter.clearBadge();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'updateBadge');
      expect(calls.single.arguments, {'count': 0});
    });
  });
}
