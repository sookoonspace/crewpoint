import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/device_timezone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalNameDeviceTimezone (fallback)', () {
    test(
      'returns DateTime.now().timeZoneName when non-empty; "UTC" otherwise',
      () async {
        // The fallback's only behavior is to surface whatever the
        // platform-default name is. We can't assert a specific value
        // (varies by test host) but we can pin "never returns empty".
        final tz = await const LocalNameDeviceTimezone().getLocalTimezone();
        expect(tz, isNotEmpty);
      },
    );
  });

  group('MethodChannelDeviceTimezone', () {
    const channel = MethodChannel('crewpoint/device_info');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns the IANA string the native handler emits', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getLocalTimezone');
            return 'America/New_York';
          });

      final tz = await const MethodChannelDeviceTimezone().getLocalTimezone();

      expect(tz, 'America/New_York');
    });

    test(
      'falls back to "UTC" when the platform call throws (web / desktop)',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              throw MissingPluginException('no impl');
            });

        final tz = await const MethodChannelDeviceTimezone().getLocalTimezone();

        expect(tz, 'UTC');
      },
    );

    test('falls back to "UTC" when native returns an empty string', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => '');

      final tz = await const MethodChannelDeviceTimezone().getLocalTimezone();

      expect(tz, 'UTC');
    });
  });
}
