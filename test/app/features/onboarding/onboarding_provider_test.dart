import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/onboarding/application/onboarding_provider.dart';

import 'fake_secure_storage.dart';

void main() {
  late FakeSecureStorage fakeStorage;
  late ProviderContainer container;
  late NotifierProvider<OnboardingNotifier, bool> onboardingProvider;

  setUp(() {
    fakeStorage = FakeSecureStorage();

    onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
      () => OnboardingNotifier(storageService: fakeStorage),
    );

    container = ProviderContainer();
    container.read(onboardingProvider);
  });

  tearDown(() => container.dispose());

  test('first launch shows onboarding (false)', () {
    final state = container.read(onboardingProvider);
    expect(state, isFalse);
  });

  test('after completeOnboarding, state is true', () async {
    await container.read(onboardingProvider.notifier).completeOnboarding();

    final state = container.read(onboardingProvider);
    expect(state, isTrue);
  });

  test('checkOnboardingStatus reads persisted value', () async {
    fakeStorage.data['onboarding_complete'] = 'true';

    await container.read(onboardingProvider.notifier).checkOnboardingStatus();

    final state = container.read(onboardingProvider);
    expect(state, isTrue);
  });
}
