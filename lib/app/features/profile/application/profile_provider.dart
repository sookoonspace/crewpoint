import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

class ProfileNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  void setUser(AppUser user) => state = user;

  void clear() => state = null;
}
