import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/models/notification_prefs.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// Hand-rolled fake [IUserRepository] for `AuthNotifier` tests.
///
/// Captures every `createUserIfNotExists` invocation as a [_CreateCall]
/// so tests can assert on count + arguments. Other methods are no-op
/// stubs because `AuthNotifier` only invokes `createUserIfNotExists`.
class FakeUserRepository implements IUserRepository {
  final List<CreateCall> createCalls = [];

  /// When set, the next `createUserIfNotExists` call throws this object.
  Object? nextCreateError;

  @override
  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    List<String> providerIds = const [],
  }) async {
    createCalls.add(
      CreateCall(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        providerIds: providerIds,
      ),
    );
    final err = nextCreateError;
    if (err != null) {
      nextCreateError = null;
      throw err;
    }
  }

  @override
  Future<AppUser?> getUser(String uid) async => null;

  @override
  Future<void> saveProfile({
    required String uid,
    required String displayName,
    String? photoUrl,
    String? paymentMethod,
    String? paymentHandle,
    String? venmoHandle,
    String? cashappHandle,
  }) async {}

  @override
  Future<void> addFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {}

  @override
  Future<void> removeFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {}

  @override
  Future<NotificationPrefs> getNotificationPrefs(String uid) async =>
      const NotificationPrefs();

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required NotificationPrefs prefs,
  }) async {}
}

class CreateCall {
  const CreateCall({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.providerIds,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> providerIds;
}
