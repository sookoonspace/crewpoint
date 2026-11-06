import 'dart:developer';

import 'package:crewpoint_app/app/core/version/app_version.dart';

/// Reads the public `config/app` document. Returns null when it is missing.
abstract class IAppConfigSource {
  Future<Map<String, dynamic>?> read();
}

class AppInfo {
  const AppInfo({required this.version, required this.packageName});
  final String version;
  final String packageName;
}

/// The running app's own version, from `package_info_plus` in production.
abstract class IAppInfo {
  Future<AppInfo> load();
}

enum AppPlatform { android, ios, web, other }

/// What the app needs before it can be used: a newer version.
class AppUpdateRequirement {
  const AppUpdateRequirement({required this.minimum, this.storeUrl});
  final String minimum;
  final Uri? storeUrl;
}

class AppVersionCheck {
  const AppVersionCheck({
    required this.config,
    required this.appInfo,
    required this.platform,
    this.timeout = const Duration(seconds: 5),
  });

  final IAppConfigSource config;
  final IAppInfo appInfo;
  final AppPlatform platform;

  /// How long startup waits for the config before carrying on without it.
  final Duration timeout;

  /// Never throws: if the config cannot be read in time, the app continues.
  Future<AppUpdateRequirement?> run() async {
    try {
      return await _run().timeout(timeout);
    } catch (e, st) {
      log('App version check skipped', error: e, stackTrace: st, name: 'app');
      return null;
    }
  }

  Future<AppUpdateRequirement?> _run() async {
    final data = await config.read();
    final minimum = data?['minVersion'];
    if (minimum is! String) return null;
    final info = await appInfo.load();
    if (!isBelowMinimum(current: info.version, minimum: minimum)) return null;
    return AppUpdateRequirement(
      minimum: minimum,
      storeUrl: _storeUrl(data?['storeUrls'], info.packageName),
    );
  }

  /// The config's link for this platform. Android falls back to the Play
  /// Store page for the package; iOS needs the App Store ID, so it has no
  /// fallback. Web reloads instead.
  Uri? _storeUrl(Object? storeUrls, String packageName) {
    final key = switch (platform) {
      AppPlatform.android => 'android',
      AppPlatform.ios => 'ios',
      AppPlatform.web || AppPlatform.other => null,
    };
    if (key == null) return null;
    final configured = storeUrls is Map ? storeUrls[key] : null;
    if (configured is String && configured.isNotEmpty) {
      return Uri.tryParse(configured);
    }
    if (platform == AppPlatform.android) {
      return Uri.https('play.google.com', '/store/apps/details', {
        'id': packageName,
      });
    }
    return null;
  }
}
