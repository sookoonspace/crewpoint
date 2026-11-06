import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/page_reloader.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/core/version/app_version_check.dart';
import 'package:crewpoint_app/app/core/widgets/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Config implements IAppConfigSource {
  _Config(this.data, {this.fails = false});
  final Map<String, dynamic>? data;
  final bool fails;
  @override
  Future<Map<String, dynamic>?> read() async {
    if (fails) throw StateError('permission-denied');
    return data;
  }
}

class _Info implements IAppInfo {
  const _Info();
  @override
  Future<AppInfo> load() async =>
      const AppInfo(version: '1.2.0', packageName: 'com.example.app');
}

class _Launcher implements IUrlLauncher {
  final launched = <Uri>[];
  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return true;
  }
}

class _Reloader implements IPageReloader {
  var reloads = 0;
  @override
  void reload() => reloads++;
}

const _home = Key('test.home');
const _screen = Key('app.update.screen');
const _store = Key('app.update.store');
const _reload = Key('app.update.reload');

Future<({_Launcher launcher, _Reloader reloader})> _pump(
  WidgetTester tester, {
  required AppPlatform platform,
  Map<String, dynamic>? config,
  bool fails = false,
}) async {
  final launcher = _Launcher();
  final reloader = _Reloader();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigSourceProvider.overrideWithValue(
          _Config(config, fails: fails),
        ),
        appInfoProvider.overrideWithValue(const _Info()),
        appPlatformProvider.overrideWithValue(platform),
        urlLauncherProvider.overrideWithValue(launcher),
        pageReloaderProvider.overrideWithValue(reloader),
      ],
      child: MaterialApp(
        builder: (context, child) => AppUpdateGate(child: child!),
        home: const Scaffold(body: Text('Home', key: _home)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (launcher: launcher, reloader: reloader);
}

void main() {
  const below = {'minVersion': '2.0.0'};
  const atMinimum = {'minVersion': '1.2.0'};

  for (final platform in AppPlatform.values) {
    group(platform.name, () {
      testWidgets('below the minimum shows the full-screen message', (
        tester,
      ) async {
        await _pump(tester, platform: platform, config: below);
        expect(find.byKey(_screen), findsOneWidget);
        expect(find.byKey(_home), findsNothing);
      });

      testWidgets('at the minimum shows the app', (tester) async {
        await _pump(tester, platform: platform, config: atMinimum);
        expect(find.byKey(_screen), findsNothing);
        expect(find.byKey(_home), findsOneWidget);
      });

      testWidgets('when the config cannot be read, shows the app', (
        tester,
      ) async {
        await _pump(tester, platform: platform, fails: true);
        expect(find.byKey(_screen), findsNothing);
        expect(find.byKey(_home), findsOneWidget);
      });
    });
  }

  testWidgets('Android opens the store link', (tester) async {
    final fakes = await _pump(
      tester,
      platform: AppPlatform.android,
      config: below,
    );
    expect(find.byKey(_reload), findsNothing);
    await tester.tap(find.byKey(_store));
    expect(fakes.launcher.launched, [
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.example.app',
      ),
    ]);
  });

  testWidgets('iOS opens the configured store link', (tester) async {
    final fakes = await _pump(
      tester,
      platform: AppPlatform.ios,
      config: {
        ...below,
        'storeUrls': {'ios': 'https://apps.apple.com/app/id1'},
      },
    );
    await tester.tap(find.byKey(_store));
    expect(fakes.launcher.launched, [
      Uri.parse('https://apps.apple.com/app/id1'),
    ]);
  });

  testWidgets('iOS without a link tells the person to use their store', (
    tester,
  ) async {
    await _pump(tester, platform: AppPlatform.ios, config: below);
    expect(find.byKey(_store), findsNothing);
    expect(
      find.text('Get the latest version from your app store.'),
      findsOneWidget,
    );
  });

  testWidgets('web reloads instead of linking to a store', (tester) async {
    final fakes = await _pump(tester, platform: AppPlatform.web, config: below);
    expect(find.byKey(_store), findsNothing);
    await tester.tap(find.byKey(_reload));
    expect(fakes.reloader.reloads, 1);
  });
}
