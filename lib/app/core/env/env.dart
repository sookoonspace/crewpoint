// Environment configuration using envied.
// Run `dart run build_runner build -d` after populating .env to generate env.g.dart.
//
// Uncomment the code below once .env has real values and run build_runner:
//
// import 'package:envied/envied.dart';
//
// part 'env.g.dart';
//
// @Envied(path: '.env')
// abstract class Env {
//   @EnviedField(varName: 'FIREBASE_API_KEY', obfuscate: true)
//   static final String firebaseApiKey = _Env.firebaseApiKey;
//
//   @EnviedField(varName: 'FIREBASE_APP_ID', obfuscate: true)
//   static final String firebaseAppId = _Env.firebaseAppId;
//
//   @EnviedField(varName: 'FIREBASE_MESSAGING_SENDER_ID', obfuscate: true)
//   static final String firebaseMessagingSenderId =
//       _Env.firebaseMessagingSenderId;
//
//   @EnviedField(varName: 'FIREBASE_PROJECT_ID', obfuscate: true)
//   static final String firebaseProjectId = _Env.firebaseProjectId;
// }

/// Placeholder until envied is configured with real keys.
abstract final class Env {
  static const String firebaseApiKey = 'PLACEHOLDER';
  static const String firebaseAppId = 'PLACEHOLDER';
  static const String firebaseMessagingSenderId = 'PLACEHOLDER';
  static const String firebaseProjectId = 'PLACEHOLDER';
}
