/// Routes FCM events into the app:
/// * foreground messages → show in-app banner unless the active route is
///   already the chat screen for that event (`/dashboard/event/{eid}/chat`)
/// * tap-from-background / cold-start tap → deep-link via the supplied
///   navigator callback
///
/// Pure logic so the lifecycle decisions are unit-testable. The platform
/// wiring (subscribing to `FirebaseMessaging.onMessage` etc.) lives in
/// `FcmHandlerBootstrap` (Phase 8.5 / `main.dart`).
class FcmHandler {
  FcmHandler({
    required this.currentRoute,
    required this.showBanner,
    required this.navigateTo,
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
}
