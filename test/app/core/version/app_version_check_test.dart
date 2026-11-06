import 'dart:async';

import 'package:crewpoint_app/app/core/version/app_version_check.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConfig implements IAppConfigSource {
  _FakeConfig(this.data);
  final Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
}

class _ThrowingConfig implements IAppConfigSource {
  @override
  Future<Map<String, dynamic>?> read() async => throw StateError('offline');
}

class _HangingConfig implements IAppConfigSource {
  @override
  Future<Map<String, dynamic>?> read() =>
      Completer<Map<String, dynamic>?>().future;
}

class _FakeInfo implements IAppInfo {
  const _FakeInfo(this.version);
  final String version;
  @override
  Future<AppInfo> load() async =>
      AppInfo(version: version, packageName: 'com.example.app');
}

AppVersionCheck _check(
  Map<String, dynamic>? config, {
  String version = '1.2.0',
  AppPlatform platform = AppPlatform.android,
}) => AppVersionCheck(
  config: _FakeConfig(config),
  appInfo: _FakeInfo(version),
  platform: platform,
);

void main() {
  test('with no config, no update is required', () async {
    expect(await _check(null).run(), isNull);
  });

  test('below the minimum, an update is required', () async {
    final result = await _check({'minVersion': '1.3.0'}).run();
    expect(result?.minimum, '1.3.0');
  });

  group('store link', () {
    const urls = {
      'minVersion': '9.0.0',
      'storeUrls': {
        'ios': 'https://apps.apple.com/app/id1',
        'android': 'https://play.example/app',
      },
    };

    test('uses the config link for the platform', () async {
      final ios = await _check(urls, platform: AppPlatform.ios).run();
      final android = await _check(urls, platform: AppPlatform.android).run();
      expect(ios?.storeUrl, Uri.parse('https://apps.apple.com/app/id1'));
      expect(android?.storeUrl, Uri.parse('https://play.example/app'));
    });

    test('Android falls back to the Play Store page for the app', () async {
      final result = await _check({'minVersion': '9.0.0'}).run();
      expect(
        result?.storeUrl,
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.example.app',
        ),
      );
    });

    test('iOS without a config link and web have no link', () async {
      final ios = await _check({
        'minVersion': '9.0.0',
      }, platform: AppPlatform.ios).run();
      final web = await _check(urls, platform: AppPlatform.web).run();
      expect(ios, isNotNull);
      expect(ios?.storeUrl, isNull);
      expect(web, isNotNull);
      expect(web?.storeUrl, isNull);
    });
  });

  test('at the minimum, no update is required', () async {
    expect(await _check({'minVersion': '1.2.0'}).run(), isNull);
  });

  test('if the config cannot be read, the app continues normally', () async {
    final check = AppVersionCheck(
      config: _ThrowingConfig(),
      appInfo: const _FakeInfo('1.0.0'),
      platform: AppPlatform.android,
    );
    expect(await check.run(), isNull);
  });

  test('if the read hangs, the app continues after the timeout', () async {
    final check = AppVersionCheck(
      config: _HangingConfig(),
      appInfo: const _FakeInfo('1.0.0'),
      platform: AppPlatform.android,
      timeout: const Duration(milliseconds: 20),
    );
    expect(await check.run(), isNull);
  });
}
