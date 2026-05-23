import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production override happens in `main()` after
/// `SharedPreferences.getInstance()` resolves; tests override via
/// `sharedPreferencesProvider.overrideWithValue(...)`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  ),
);

/// Persistence key. Versioned so a future format migration can branch
/// without colliding with the v1 string layout.
const themeModeStorageKey = 'theme_mode_v1';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = _readPrefs();
    if (prefs == null) return ThemeMode.system;
    final stored = prefs.getString(themeModeStorageKey);
    return _parse(stored);
  }

  /// Updates state immediately and fires off a persistence write. The
  /// write is intentionally not awaited — UI does not block on disk and
  /// a failed write still leaves the in-memory mode correct for the
  /// current session.
  void set(ThemeMode mode) {
    state = mode;
    final prefs = _readPrefs();
    if (prefs == null) return;
    unawaited(
      prefs.setString(themeModeStorageKey, _serialize(mode)).catchError((
        Object error,
        StackTrace stack,
      ) {
        developer.log(
          'Failed to persist theme mode',
          name: 'theme',
          error: error,
          stackTrace: stack,
        );
        return false;
      }),
    );
  }

  /// Tolerate a missing `sharedPreferencesProvider` override by logging
  /// once and falling back to the system theme. Production overrides
  /// in `main()`; widget tests that don't care about theme persistence
  /// (most of them) get a safe default without needing to wire prefs.
  SharedPreferences? _readPrefs() {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (error, stack) {
      developer.log(
        'sharedPreferencesProvider not overridden — theme will not persist',
        name: 'theme',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _serialize(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
