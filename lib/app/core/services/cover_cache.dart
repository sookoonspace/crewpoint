import 'dart:typed_data';

/// Keeps cover photos on the device, so an event's banner and thumbnail
/// show on an offline cold start once loaded before (Spec #186 Req 43).
/// Keyed by Storage path and change time: a replaced photo has a new key,
/// so a stale copy is never shown.
abstract interface class ICoverCache {
  Future<Uint8List?> read(String path, DateTime updatedAt);

  /// Stores [bytes] for this version and drops older versions of [path].
  Future<void> write(String path, DateTime updatedAt, Uint8List bytes);
}

/// The file name for one version of a cover, safe on every file system.
String coverCacheName(String path, DateTime updatedAt) =>
    '${coverCachePrefix(path)}${updatedAt.toUtc().millisecondsSinceEpoch}';

/// What every version of [path] starts with.
String coverCachePrefix(String path) =>
    '${path.replaceAll(RegExp('[^A-Za-z0-9]'), '_')}@';

/// Holds covers in memory: the web build, whose Drift is in memory too, and
/// tests.
class MemoryCoverCache implements ICoverCache {
  final _files = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String path, DateTime updatedAt) async =>
      _files[coverCacheName(path, updatedAt)];

  @override
  Future<void> write(String path, DateTime updatedAt, Uint8List bytes) async {
    final prefix = coverCachePrefix(path);
    _files
      ..removeWhere((name, _) => name.startsWith(prefix))
      ..[coverCacheName(path, updatedAt)] = bytes;
  }
}
