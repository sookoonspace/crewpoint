import 'dart:developer';

import 'package:flutter/services.dart';

/// Resolves the device's IANA timezone identifier
/// (e.g. `"America/New_York"`). Required server-side for the Phase 5
/// quiet-hours window — the CF reads it via
/// `Intl.DateTimeFormat({timeZone: ...})` to convert UTC pushes into
/// the recipient's wall clock.
///
/// Production wires [MethodChannelDeviceTimezone]; tests inject a
/// recording fake or [LocalNameDeviceTimezone] for non-Flutter contexts.
abstract class IDeviceTimezone {
  Future<String> getLocalTimezone();
}

/// Production adapter — calls into the native runtime over a dedicated
/// MethodChannel. Native handlers live in:
/// * `android/app/src/main/kotlin/.../MainActivity.kt` →
///   `TimeZone.getDefault().id`
/// * `ios/Runner/AppDelegate.swift` → `TimeZone.current.identifier`
///
/// Returns `"UTC"` as a safe fallback when the platform call throws
/// (web / desktop / unimplemented method). The server treats unknown
/// IANA strings as "no quiet hours" so a `UTC` fallback is benign —
/// the worst case is the user's quiet-hours window is interpreted in
/// UTC instead of their local time.
class MethodChannelDeviceTimezone implements IDeviceTimezone {
  const MethodChannelDeviceTimezone({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'crewpoint/device_info';
  static const String methodGetLocalTimezone = 'getLocalTimezone';

  final MethodChannel _channel;

  @override
  Future<String> getLocalTimezone() async {
    try {
      final raw = await _channel.invokeMethod<String>(methodGetLocalTimezone);
      if (raw == null || raw.isEmpty) return 'UTC';
      return raw;
    } catch (e, st) {
      log(
        'getLocalTimezone platform call failed; falling back to UTC',
        error: e,
        stackTrace: st,
        name: 'fcm',
      );
      return 'UTC';
    }
  }
}

/// Fallback / test seam — surfaces `DateTime.now().timeZoneName`. On
/// Android this is usually the IANA name; on iOS it's the abbreviation
/// (e.g. `"EDT"`) which Intl.DateTimeFormat doesn't recognize.
/// Defaults to `"UTC"` when the platform returns an empty string.
class LocalNameDeviceTimezone implements IDeviceTimezone {
  const LocalNameDeviceTimezone();

  @override
  Future<String> getLocalTimezone() async {
    final raw = DateTime.now().timeZoneName.trim();
    return raw.isEmpty ? 'UTC' : raw;
  }
}
