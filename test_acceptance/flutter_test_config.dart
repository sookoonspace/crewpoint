import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';

/// The app loads label defaults at startup, and tests read the same file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initEventTimeZones();
  LabelDefaults.current = LabelDefaults.fromJson(
    jsonDecode(File(LabelDefaults.assetPath).readAsStringSync())
        as Map<String, dynamic>,
  );
  await testMain();
}
