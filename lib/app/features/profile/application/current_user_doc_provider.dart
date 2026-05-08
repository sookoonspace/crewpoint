import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

/// Streams the Firestore-backed [AppUser] for the currently authenticated
/// session.
///
/// Emits `null` when unauthenticated. While authenticated, subscribes to
/// `users/{uid}` and emits a merged [AppUser] on every snapshot:
///
///   * `displayName`, `photoUrl`, payment fields, currency  ← Firestore public doc
///   * `email`, `emailVerified`, `providerIds`              ← Firebase Auth metadata
///
/// When the public doc has not been materialised yet (the brief window
/// between `Authenticated` and `_ensureUserDoc` completing), the stream
/// emits the auth-only [AppUser] so the UI never shows a stale empty
/// state. Once Firestore writes the doc, the next snapshot supersedes it.
final currentUserDocProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth is! Authenticated) {
    return Stream.value(null);
  }
  final firestore = ref.watch(firestoreProvider);
  final authUser = auth.user;
  return firestore.collection('users').doc(authUser.uid).snapshots().map((
    snap,
  ) {
    final data = snap.exists ? snap.data() : null;
    if (data == null) return authUser;
    return AppUser(
      uid: authUser.uid,
      email: authUser.email,
      displayName: (data['displayName'] as String?) ?? authUser.displayName,
      photoUrl: (data['photoUrl'] as String?) ?? authUser.photoUrl,
      paymentMethod: data['paymentMethod'] as String?,
      paymentHandle: data['paymentHandle'] as String?,
      venmoHandle: data['venmoHandle'] as String?,
      cashappHandle: data['cashappHandle'] as String?,
      currency: (data['currency'] as String?) ?? 'USD',
      emailVerified: authUser.emailVerified,
      providerIds: authUser.providerIds,
    );
  });
});
