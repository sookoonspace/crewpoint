import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';

const _onboardingCompleteKey = 'onboarding_complete';

class OnboardingNotifier extends Notifier<bool> {
  OnboardingNotifier({required SecureStorageService storageService})
    : _storageService = storageService;

  final SecureStorageService _storageService;

  @override
  bool build() => false;

  Future<void> checkOnboardingStatus() async {
    final value = await _storageService.read(_onboardingCompleteKey);
    state = value == 'true';
  }

  Future<void> completeOnboarding() async {
    await _storageService.write(key: _onboardingCompleteKey, value: 'true');
    state = true;
  }
}
