import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

/// Answers kept on the device as they are typed (Spec #233 Req 23, TD 8;
/// #243): one draft per key, such as an event and a person, saved, loaded
/// and cleared. Tests use a memory fake (`test/harness/memory_draft_store.dart`).
abstract interface class IDraftStore {
  Future<Map<String, Object?>?> load(String key);
  Future<void> save(String key, Map<String, Object?> draft);
  Future<void> clear(String key);
}

/// Keeps drafts as JSON in [SharedPreferences]: the browser's local storage
/// on the web, the app's own storage on phones. Something unreadable loads
/// as no draft.
class SharedPreferencesDraftStore implements IDraftStore {
  const SharedPreferencesDraftStore(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'draft_v1:';

  @override
  Future<Map<String, Object?>?> load(String key) async {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map<String, Object?> ? data : null;
    } on FormatException catch (e, st) {
      log('Unreadable draft $key', error: e, stackTrace: st, name: 'drafts');
      return null;
    }
  }

  @override
  Future<void> save(String key, Map<String, Object?> draft) =>
      _prefs.setString('$_prefix$key', jsonEncode(draft));

  @override
  Future<void> clear(String key) => _prefs.remove('$_prefix$key');
}
