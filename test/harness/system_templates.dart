import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_template.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The system templates read straight from `assets/templates/`, so widget
/// tests do not wait on the asset bundle.
List<EventTemplateInfo> systemTemplatesFromFiles() {
  Map<String, dynamic> read(String file) =>
      jsonDecode(File('${EventTemplateInfo.assetDir}/$file').readAsStringSync())
          as Map<String, dynamic>;
  return [
    for (final id in EventTemplateInfo.idsFrom(read('index.json')))
      EventTemplateInfo.fromJson(read('$id.json')),
  ];
}

Override systemTemplatesOverride() => templateCatalogueProvider.overrideWith(
  (ref) async => systemTemplatesFromFiles(),
);
