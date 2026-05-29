import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer makeContainer(SharedPreferences prefs) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to ThemeMode.system when no preference is stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('hydrates ThemeMode.dark from stored preference', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode_v1': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('hydrates ThemeMode.light from stored preference', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode_v1': 'light',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('set(ThemeMode.dark) updates state and persists to prefs', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);

    container.read(themeModeProvider.notifier).set(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    // Allow the fire-and-forget write to complete.
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString('theme_mode_v1'), 'dark');
  });

  test('set(ThemeMode.system) writes "system" to prefs', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode_v1': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = makeContainer(prefs);

    container.read(themeModeProvider.notifier).set(ThemeMode.system);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(prefs.getString('theme_mode_v1'), 'system');
  });
}
