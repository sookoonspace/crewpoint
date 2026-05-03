import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';

/// Secure-storage key for the "onboarding complete" flag.
///
/// Public so [AccountDeletionService._clearLocalData] can re-pin it after
/// `secureStorage.deleteAll()` wipes secure storage during account deletion.
/// Without the re-pin, a user who deletes their account on a device would
/// be forced back through onboarding on next sign-up on the same device.
const onboardingCompleteKey = 'onboarding_complete';

class OnboardingNotifier extends Notifier<bool> {
  OnboardingNotifier({required SecureStorageService storageService})
    : _storageService = storageService;

  final SecureStorageService _storageService;

  @override
  bool build() => false;

  Future<void> checkOnboardingStatus() async {
    final value = await _storageService.read(onboardingCompleteKey);
    state = value == 'true';
  }

  Future<void> completeOnboarding() async {
    await _storageService.write(key: onboardingCompleteKey, value: 'true');
    state = true;
  }
}
