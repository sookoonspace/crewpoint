import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';

/// Links the signed-in account to its own participant records (Req 46,
/// X-05, L-01, L-02). Once someone is signed in with a verified email, by
/// Google, Apple or a verified password, it asks the server once per account
/// per session; an unverified email waits until the person verifies it. The
/// server decides what links. Holds the last result, so the shell can say
/// what was linked.
class AccountLinker extends Notifier<LinkResult?> {
  final _asked = <String>{};

  @override
  LinkResult? build() {
    ref.listen<AuthState>(
      authProvider,
      (_, next) => unawaited(_check(next)),
      fireImmediately: true,
    );
    return null;
  }

  Future<void> _check(AuthState auth) async {
    if (auth is! Authenticated || !auth.user.emailVerified) return;
    final uid = auth.user.uid;
    if (!_asked.add(uid)) return;
    try {
      state = await ref.read(memberCallsProvider).linkMyParticipants();
    } catch (_) {
      // Offline or a server error: tried again the next time they sign in.
      _asked.remove(uid);
    }
  }
}

final accountLinkerProvider = NotifierProvider<AccountLinker, LinkResult?>(
  AccountLinker.new,
);
