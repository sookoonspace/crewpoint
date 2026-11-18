import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:crewpoint_app/app/core/services/cover_cache.dart';

/// Keeps covers as files in the app's support folder.
class FileCoverCache implements ICoverCache {
  Directory? _dir;

  Future<Directory> _folder() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/covers');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  @override
  Future<Uint8List?> read(String path, DateTime updatedAt) async {
    try {
      final file = File(
        '${(await _folder()).path}/${coverCacheName(path, updatedAt)}',
      );
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (e, st) {
      log('Cover cache read failed', error: e, stackTrace: st, name: 'cover');
      return null;
    }
  }

  @override
  Future<void> write(String path, DateTime updatedAt, Uint8List bytes) async {
    try {
      final dir = await _folder();
      final prefix = coverCachePrefix(path);
      await for (final entry in dir.list()) {
        if (entry is File && entry.uri.pathSegments.last.startsWith(prefix)) {
          await entry.delete();
        }
      }
      await File(
        '${dir.path}/${coverCacheName(path, updatedAt)}',
      ).writeAsBytes(bytes, flush: true);
    } catch (e, st) {
      log('Cover cache write failed', error: e, stackTrace: st, name: 'cover');
    }
  }
}

ICoverCache createCoverCache() => FileCoverCache();
