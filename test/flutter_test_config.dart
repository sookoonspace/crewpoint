import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';

/// The app loads label defaults and role presets at startup, and tests read
/// the same files.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initEventTimeZones();
  LabelDefaults.current = LabelDefaults.fromJson(
    jsonDecode(File(LabelDefaults.assetPath).readAsStringSync())
        as Map<String, dynamic>,
  );
  RoleCatalogue.current = RoleCatalogue.fromJson(
    jsonDecode(File(RoleCatalogue.assetPath).readAsStringSync())
        as Map<String, dynamic>,
  );
  await testMain();
}
