import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

/// Resolves event-member display info on demand.
///
/// V1 fetches each `users/{uid}` doc once per build via the existing
/// [userRepositoryProvider]; results are cached for the lifetime of the
/// provider scope. Phase 8 may upgrade this to a live subscription.
final usersByIdProvider =
    FutureProvider.family<Map<String, AppUser>, List<String>>((
      ref,
      uids,
    ) async {
      final repo = ref.watch(userRepositoryProvider);
      final result = <String, AppUser>{};
      for (final uid in uids) {
        final user = await repo.getUser(uid);
        if (user != null) result[uid] = user;
      }
      return result;
    });
