import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

/// Resolves event-member display info on demand.
///
/// V1 fetches each `users/{uid}` doc once per build via the existing
/// [userRepositoryProvider]; results are cached for the lifetime of the
/// provider scope.
///
/// **Family-key contract:** the family parameter is a `String` of
/// **sorted, comma-joined UIDs** — NOT a `List<String>`. Dart Lists use
/// identity equality; passing a fresh `List` on every build (the natural
/// pattern when the call site composes `[...event.memberIds,
/// task.assigneeId]`) made Riverpod cache-miss every frame, refire the
/// Futures, and reset every consumer's state to loading on each rebuild
/// — which manifested as "Unknown member" never resolving. The String
/// key has stable value-equality so the cache hits on identical
/// member sets.
///
/// Use [usersByIds] helper to build the key correctly.
final usersByIdProvider = FutureProvider.family<Map<String, AppUser>, String>((
  ref,
  key,
) async {
  final uids = key.isEmpty ? const <String>[] : key.split(',');
  final repo = ref.watch(userRepositoryProvider);
  final result = <String, AppUser>{};
  for (final uid in uids) {
    final user = await repo.getUser(uid);
    if (user != null) result[uid] = user;
  }
  return result;
});

/// Builds the stable family key for [usersByIdProvider]. Dedupes and
/// sorts so two equivalent uid sets share a cache entry.
String usersByIds(Iterable<String> uids) {
  final unique = uids.where((u) => u.isNotEmpty).toSet().toList()..sort();
  return unique.join(',');
}
