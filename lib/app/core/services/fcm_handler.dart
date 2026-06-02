/// Routes FCM events into the app:
/// * foreground messages → show in-app banner unless the active route is
///   already the chat screen for that event (`/dashboard/event/{eid}/chat`)
/// * tap-from-background / cold-start tap → deep-link via the supplied
///   navigator callback
/// * iOS notification action button (`MARK_DONE`) → invoke the
///   `markTaskDone` callback so the task transitions to done without
///   opening the app. The action identifier is delivered via
///   `data['action']`; the iOS bridge in `AppDelegate.swift` copies
///   `UNNotificationResponse.actionIdentifier` into the notification
///   `userInfo` before `firebase_messaging` surfaces the payload.
///
/// Pure logic so the lifecycle decisions are unit-testable. The platform
/// wiring (subscribing to `FirebaseMessaging.onMessage` etc.) lives in
/// `FcmHandlerBootstrap` (Phase 8.5 / `main.dart`).
class FcmHandler {
  FcmHandler({
    required this.currentRoute,
    required this.showBanner,
    required this.navigateTo,
    this.markTaskDone,
  });

  /// Reads the current go_router location.
  final String? Function() currentRoute;

  /// Renders the in-app foreground banner.
  final void Function({
    required String title,
    required String body,
    required String deepLink,
  })
  showBanner;

  /// Performs the deep-link navigation.
  final void Function(String deepLink) navigateTo;

  /// Routes the iOS `MARK_DONE` action to the `markTaskComplete` callable
  /// (or any other write path) — injected from the composition root so
  /// `FcmHandler` stays free of `cloud_functions` imports. Optional so
  /// existing callers that pre-date interactive actions keep compiling.
  final void Function({required String eventId, required String taskId})?
  markTaskDone;

  /// Returns true if the foreground message was suppressed because the user
  /// is already on the relevant chat screen.
  bool handleForegroundMessage({
    required String title,
    required String body,
    required Map<String, String> data,
  }) {
    final eventId = data['eventId'];
    final deepLink = data['deepLink'] ?? '/dashboard';
    if (eventId != null) {
      final route = currentRoute();
      if (route != null && route.endsWith('/event/$eventId/chat')) {
        // Already on chat — do not banner-spam.
        return true;
      }
    }
    showBanner(title: title, body: body, deepLink: deepLink);
    return false;
  }

  /// Tapped a notification (background or cold start) — deep-link.
  void handleTap({required Map<String, String> data}) {
    final deepLink = data['deepLink'];
    if (deepLink != null && deepLink.isNotEmpty) {
      navigateTo(deepLink);
    }
  }

  /// Dispatches an iOS notification-action tap (see class doc). Caller is
  /// responsible for routing this from the same `onMessageOpenedApp` /
  /// cold-start path that feeds [handleTap] — the bridge only differs by
  /// the presence of `data['action']`.
  void handleAction({required Map<String, String> data}) {
    final action = data['action'];
    if (action == null || action.isEmpty) return;
    switch (action) {
      case 'mark_done':
        final eventId = data['eventId'];
        final taskId = data['taskId'];
        if (eventId == null ||
            eventId.isEmpty ||
            taskId == null ||
            taskId.isEmpty) {
          return;
        }
        markTaskDone?.call(eventId: eventId, taskId: taskId);
      default:
        // Unknown action — no-op so a future server-side action that
        // ships before its client handler does no damage on older builds.
        return;
    }
  }
}
