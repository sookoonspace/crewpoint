import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:crewpoint_app/app/core/env/env.dart';

/// Starts Firebase App Check (Spec #233 Req 13a, Technical Decision 13),
/// which the public event page and personal-link calls require. Called
/// only from `main`, like the crash reporter, so tests and emulator runs
/// never need a real token.
///
/// The web uses reCAPTCHA Enterprise with the flavor's site key
/// (`APP_CHECK_WEB_KEY` in `.env.<flavor>`); without one, App Check stays
/// off on the web and public calls are refused by deployed functions.
/// Debug builds use the debug providers, whose tokens are registered in the
/// Firebase console.
abstract final class AppCheckStarter {
  static Future<void> start() async {
    if (kIsWeb && Env.appCheckWebKey.isEmpty) {
      developer.log(
        'APP_CHECK_WEB_KEY is not set; App Check is off on the web.',
        name: 'appCheck',
      );
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: kIsWeb
            ? ReCaptchaEnterpriseProvider(Env.appCheckWebKey)
            : null,
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    } catch (e, st) {
      // Only the public calls need it, so the rest of the app carries on.
      developer.log(
        'App Check failed to start',
        name: 'appCheck',
        error: e,
        stackTrace: st,
      );
    }
  }
}
