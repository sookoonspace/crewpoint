import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/version/app_version_check.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads `config/app`, which rules leave public so it works before sign-in.
class FirestoreAppConfigSource implements IAppConfigSource {
  const FirestoreAppConfigSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, dynamic>?> read() async {
    final snapshot = await _firestore.doc('config/app').get();
    return snapshot.data();
  }
}

class PackageInfoAppInfo implements IAppInfo {
  const PackageInfoAppInfo();

  @override
  Future<AppInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(version: info.version, packageName: info.packageName);
  }
}

AppPlatform currentAppPlatform() {
  if (kIsWeb) return AppPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AppPlatform.android,
    TargetPlatform.iOS => AppPlatform.ios,
    _ => AppPlatform.other,
  };
}
