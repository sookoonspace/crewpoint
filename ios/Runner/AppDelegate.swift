import Flutter
import UIKit
import UserNotifications
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // MARK: - UNNotificationCategory identifiers
  //
  // Server sets `apns.payload.aps.category` in
  // `functions/src/notifications/sendPush.ts`. iOS resolves it against
  // the categories registered below to decide which action buttons to
  // show under the notification.
  private static let taskCategoryId = "TASK_CATEGORY"
  private static let paymentCategoryId = "PAYMENT_CATEGORY"

  // MARK: - UNNotificationAction identifiers
  //
  // Mirrored on the Dart side as `data['action']` values
  // ("mark_done", "view_expense"). The native → Dart bridge for the
  // tapped action identifier is wired through the
  // `crewpoint/notification_actions` MethodChannel (see
  // `notificationActionChannel` below + the listener registered in
  // `FcmHandlerBootstrap`).
  private static let markDoneActionId = "MARK_DONE"
  private static let viewExpenseActionId = "VIEW_EXPENSE"

  /// `MethodChannel` carrying notification-action events to Dart.
  /// Established lazily on the first action tap — at app launch the
  /// implicit `FlutterViewController` may not be attached yet, so we
  /// resolve the binary messenger from `window.rootViewController` on
  /// demand and cache the channel once we have a working messenger.
  private var notificationActionChannel: FlutterMethodChannel?

  private func resolveNotificationActionChannel() -> FlutterMethodChannel? {
    if let cached = notificationActionChannel { return cached }
    guard
      let controller = window?.rootViewController as? FlutterViewController
    else {
      return nil
    }
    let channel = FlutterMethodChannel(
      name: "crewpoint/notification_actions",
      binaryMessenger: controller.binaryMessenger
    )
    notificationActionChannel = channel
    return channel
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerNotificationCategories()
    // Set our delegate BEFORE super so the firebase_messaging plugin saves
    // us as `_originalNotificationCenterDelegate` during its own setup —
    // that's the only path our `userNotificationCenter(_:didReceive:_)`
    // override below gets invoked once the plugin claims the delegate
    // slot for itself.
    UNUserNotificationCenter.current().delegate = self
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

  // MARK: - UNNotificationCategory registration

  private func registerNotificationCategories() {
    let markDone = UNNotificationAction(
      identifier: Self.markDoneActionId,
      title: "Mark Done",
      options: [.authenticationRequired]
    )
    let viewExpense = UNNotificationAction(
      identifier: Self.viewExpenseActionId,
      title: "View Expense",
      options: [.foreground]
    )

    let taskCategory = UNNotificationCategory(
      identifier: Self.taskCategoryId,
      actions: [markDone],
      intentIdentifiers: [],
      options: []
    )
    let paymentCategory = UNNotificationCategory(
      identifier: Self.paymentCategoryId,
      actions: [viewExpense],
      intentIdentifiers: [],
      options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories(
      [taskCategory, paymentCategory]
    )
  }

  // MARK: - Action delegate
  //
  // The firebase_messaging plugin replaces the UNUserNotificationCenter
  // delegate at plugin init and forwards `didReceive:` to whichever
  // delegate was previously set (us). The plugin emits the message via
  // `Messaging#onMessageOpenedApp` before forwarding to us, so the body
  // tap path is unchanged. For action button taps we fire a separate
  // `actionTapped` event on `crewpoint/notification_actions` carrying
  // the action identifier + key fields from `userInfo` so `FcmHandler.
  // handleAction` can route without inspecting the FCM data twice.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionId = response.actionIdentifier
    if actionId != UNNotificationDefaultActionIdentifier
      && actionId != UNNotificationDismissActionIdentifier,
      let normalized = mapActionIdentifier(actionId)
    {
      let userInfo = response.notification.request.content.userInfo
      resolveNotificationActionChannel()?.invokeMethod(
        "actionTapped",
        arguments: [
          "action": normalized,
          "eventId": userInfo["eventId"] as? String ?? "",
          "taskId": userInfo["taskId"] as? String ?? "",
          "deepLink": userInfo["deepLink"] as? String ?? "",
        ]
      )
    }

    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  private func mapActionIdentifier(_ id: String) -> String? {
    switch id {
    case Self.markDoneActionId: return "mark_done"
    case Self.viewExpenseActionId: return "view_expense"
    default: return nil
    }
  }
}
