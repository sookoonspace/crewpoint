import 'package:crewpoint_app/app/core/services/draft_store.dart';

/// Keeps drafts in memory, as a reload would find them on the device.
class MemoryDraftStore implements IDraftStore {
  final Map<String, Map<String, Object?>> drafts = {};

  @override
  Future<Map<String, Object?>?> load(String key) async => drafts[key];

  @override
  Future<void> save(String key, Map<String, Object?> draft) async =>
      drafts[key] = draft;

  @override
  Future<void> clear(String key) async => drafts.remove(key);
}
