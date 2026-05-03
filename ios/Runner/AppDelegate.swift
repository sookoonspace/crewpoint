import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Hands Google / Apple OAuth callback URLs (com.googleusercontent.apps.<id>://firebaseauth/link?...)
  /// to Firebase Auth before falling through to the Flutter engine.
  ///
  /// Without this, `Auth.auth().canHandle(url)` is bypassed by FlutterAppDelegate's
  /// default URL forwarding — the callback shows up as a deep link inside
  /// Flutter, GoRouter can't match it, and the user lands on the
  /// `_RouterErrorScreen` mid-`signInWithProvider` / `reauthenticateWithProvider`.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
