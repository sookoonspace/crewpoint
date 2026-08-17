import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/router/current_route_provider.dart';
import 'package:crewpoint_app/app/core/services/fcm_handler.dart';
import 'package:crewpoint_app/app/core/services/fcm_handler_bootstrap.dart';
import 'package:crewpoint_app/app/core/services/firebase_service.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/core/theme/theme_mode_provider.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/application/unread_badge_provider.dart';

/// Background isolate FCM handler.
///
/// MUST be a top-level (or static) function annotated with
/// `@pragma('vm:entry-point')` — Firebase Messaging spawns a NEW isolate
/// when the app is terminated and a push arrives, and the tree-shaker
/// would otherwise strip this entry. Keep it dependency-free: any
/// Riverpod / GoRouter state lives in the foreground isolate and is
/// unreachable from here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // V1: the urgent-message push already carries the deep-link in
  // `data['deepLink']`, and the OS renders the notification chrome. No
  // background work is required beyond logging the receipt for QA.
  developer.log(
    'bg push received: ${message.messageId}',
    name: 'fcm.background',
  );
}

/// Makes the native build the source of truth for the active flavor, so
/// `flutter run --flavor stg` is correct on its own.
///
/// `--flavor` selects the native build — the Android product flavor and
/// iOS scheme, and therefore which `google-services.json` /
/// `GoogleService-Info.plist` ships. The package identifier that produces
/// is unambiguous, so it can name the flavor directly rather than making
/// the caller repeat it in `--dart-define=FLAVOR=`.
///
/// This must run before [FirebaseService.initialize]. Without it, omitting
/// the define left `AppFlavor.current` at its `dev` fallback while the
/// native side was stg: Android's Firebase SDK auto-initializes
/// `[DEFAULT]` from the stg config before `main`, `initializeApp` was then
/// called with dev options, and the resulting `[core/duplicate-app]`
/// propagated out of `main` — `runApp` never executed and the app showed a
/// blank screen with nothing in the logs naming the cause.
///
/// Web is skipped: it has no native build to select, so the define stays
/// the only selector there — which is also why web takes no `--flavor`.
///
/// A define that *contradicts* the native build is still an error worth
/// reporting, since only one of the two can be honoured.
Future<void> _resolveFlavorFromNativeBuild() async {
  if (kIsWeb) return;
  final packageName = (await PackageInfo.fromPlatform()).packageName;
  final native = AppFlavor.fromAppId(packageName);
  if (native == null) {
    developer.log(
      'Unrecognised package id "$packageName"; falling back to '
      '${AppFlavor.current.name}',
      name: 'flavor',
    );
    return;
  }
  const defineWasGiven = bool.hasEnvironment('FLAVOR');
  if (defineWasGiven && AppFlavor.fromDefine != native) {
    throw StateError(
      'Flavor mismatch: the native build is "$packageName" (${native.name}) '
      'but --dart-define=FLAVOR was set to "${AppFlavor.fromDefine.name}".\n'
      'Drop the define — `flutter run --flavor ${native.name}` is enough on '
      'iOS and Android — or set both to the same flavor.',
    );
  }
  AppFlavor.resolveFromNativeAppId(packageName);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The native build names the flavor on iOS and Android, so `--flavor`
  // alone is sufficient there. Must precede FirebaseService.initialize:
  // the native Firebase SDK has already auto-initialized [DEFAULT] from
  // the per-flavor config by this point, and initializing again with a
  // different project's options throws [core/duplicate-app].
  await _resolveFlavorFromNativeBuild();
  await FirebaseService.initialize(flavor: AppFlavor.current);
  // Background isolate handler must be registered before the first FCM
  // event lands. Register early so a cold-start tap into a closed app
  // resolves correctly. No-op on web (the JS SDK handles background via
  // the service worker).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // SharedPreferences is resolved BEFORE runApp so themeModeProvider's
  // build() can read the persisted choice synchronously — no first-frame
  // flash in the wrong theme.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

/// Bridges Riverpod state changes to a [Listenable] for GoRouter's
/// `refreshListenable`. Constructed once per [MyApp] state; the
/// router is too. Any auth- or onboarding-state change triggers
/// `notifyListeners`, which causes GoRouter to re-run its redirect
/// chain WITHOUT tearing down the existing route stack (which is
/// what the old "create router on every build" pattern did).
class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final _RouterRefresh _routerRefresh;
  late final GoRouter _router;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  FcmHandlerBootstrap? _fcmBootstrap;
  String? _fcmAttachedUid;
  ProviderSubscription<UnreadBadgeCounts>? _badgeMirrorSub;

  @override
  void initState() {
    super.initState();
    // Check persisted onboarding status on startup.
    Future.microtask(
      () => ref.read(onboardingProvider.notifier).checkOnboardingStatus(),
    );

    _routerRefresh = _RouterRefresh();
    _router = createRouter(
      isOnboardingComplete: () => ref.read(onboardingProvider),
      isAuthenticated: () => ref.read(authProvider) is Authenticated,
      refreshListenable: _routerRefresh,
      // GoRouter's redirect callback fires synchronously during the
      // widget tree's build phase; Riverpod 3 forbids mutating a
      // provider mid-build. Defer the set() onto the next microtask so
      // currentRouteProvider updates after the frame settles.
      onRouteChanged: (location) {
        Future.microtask(
          () => ref.read(currentRouteProvider.notifier).set(location),
        );
      },
    );

    // Wire FCM streams once. The router is ready; the auth listener below
    // attaches the per-user token.
    _startFcmBootstrap();
  }

  Future<void> _startFcmBootstrap() async {
    final handler = FcmHandler(
      currentRoute: () => ref.read(currentRouteProvider),
      showBanner: _showForegroundBanner,
      navigateTo: _router.go,
      markTaskDone: _markTaskDoneFromNotification,
      muteEvent: _muteEventFromNotification,
    );
    final messaging = FirebaseMessaging.instance;
    final bootstrap = FcmHandlerBootstrap(
      handler: handler,
      onMessage: FirebaseMessaging.onMessage,
      onMessageOpenedApp: FirebaseMessaging.onMessageOpenedApp,
      getInitialMessage: messaging.getInitialMessage,
      onNotificationAction: _notificationActionStream(),
    );
    _fcmBootstrap = bootstrap;
    await bootstrap.start();
  }

  /// Adapts the native `crewpoint/notification_actions` MethodChannel
  /// (set up in `ios/Runner/AppDelegate.swift`) into a Dart stream of
  /// `{action, eventId, taskId, deepLink}` payloads. Android currently
  /// has no analogue — notification actions there route through
  /// PendingIntent + the existing deep-link path.
  Stream<Map<String, String>> _notificationActionStream() {
    final controller = StreamController<Map<String, String>>.broadcast();
    const channel = MethodChannel('crewpoint/notification_actions');
    channel.setMethodCallHandler((call) async {
      if (call.method != 'actionTapped') return null;
      final args = call.arguments;
      if (args is! Map) return null;
      final data = <String, String>{
        for (final entry in args.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
      controller.add(data);
      return null;
    });
    return controller.stream;
  }

  /// Bridges the iOS `MARK_DONE` notification action to the existing
  /// `markTaskComplete` Cloud Function. Fire-and-forget — failures are
  /// logged so a slow / lost network doesn't crash the app delegate
  /// callback path on iOS.
  void _markTaskDoneFromNotification({
    required String eventId,
    required String taskId,
  }) {
    unawaited(
      FirebaseFunctions.instance
          .httpsCallable('markTaskComplete')
          .call<Map<String, dynamic>>({'eventId': eventId, 'taskId': taskId})
          .then(
            (_) => developer.log(
              'mark_done dispatched for $eventId/$taskId',
              name: 'fcm',
            ),
            onError: (Object e, StackTrace st) => developer.log(
              'mark_done failed for $eventId/$taskId',
              error: e,
              stackTrace: st,
              name: 'fcm',
            ),
          ),
    );
  }

  /// Bridges the iOS `MUTE_EVENT` notification action to a direct
  /// Firestore write (`users/{uid}/eventMutes/{eventId}` via
  /// EventMuteRepository). Fire-and-forget — failures are logged.
  /// No-op when there is no authenticated uid (the action shouldn't
  /// be reachable then, but defend in case of stale notifications).
  void _muteEventFromNotification({
    required String eventId,
    required Duration duration,
  }) {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    unawaited(
      ref
          .read(eventMuteRepositoryProvider)
          .muteEvent(
            uid: uid,
            eventId: eventId,
            mutedUntil: DateTime.now().toUtc().add(duration),
          )
          .then(
            (_) => developer.log(
              'mute_event dispatched for $eventId (${duration.inHours}h)',
              name: 'fcm',
            ),
            onError: (Object e, StackTrace st) => developer.log(
              'mute_event failed for $eventId',
              error: e,
              stackTrace: st,
              name: 'fcm',
            ),
          ),
    );
  }

  void _showForegroundBanner({
    required String title,
    required String body,
    required String deepLink,
  }) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(body.isEmpty ? title : '$title — $body'),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              _router.go(deepLink);
            },
            child: const Text('View'),
          ),
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  /// Attaches the FCM token when [authProvider] transitions to
  /// [Authenticated] for a previously unattached uid; detaches on sign-out
  /// or uid change. Called from `ref.listen` in [build].
  void _syncFcmForAuth(AuthState? previous, AuthState next) {
    final nextUid = switch (next) {
      Authenticated(:final user) => user.uid,
      _ => null,
    };
    if (nextUid == _fcmAttachedUid) return;

    final attachedUid = _fcmAttachedUid;
    final service = ref.read(fcmServiceProvider);
    if (attachedUid != null) {
      // Fire-and-forget; failures are logged inside FcmService.
      unawaited(service.detach(uid: attachedUid));
    }
    if (nextUid != null) {
      unawaited(service.attach(uid: nextUid));
    }
    _fcmAttachedUid = nextUid;

    _syncBadgeMirror(nextUid);
  }

  /// Subscribes the OS app-icon badge to the current user's
  /// [unreadBadgeProvider]. Resubscribes on uid change, closes on sign-out
  /// (with an explicit clear so the badge doesn't linger).
  void _syncBadgeMirror(String? uid) {
    _badgeMirrorSub?.close();
    _badgeMirrorSub = null;
    final badgeService = ref.read(appBadgeServiceProvider);
    if (uid == null) {
      unawaited(badgeService.update(0));
      return;
    }
    _badgeMirrorSub = ref.listenManual<UnreadBadgeCounts>(
      unreadBadgeProvider(uid),
      (_, next) => unawaited(badgeService.update(next.total)),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    unawaited(_fcmBootstrap?.dispose());
    _badgeMirrorSub?.close();
    _router.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching here would rebuild MyApp on every flip and recreate the
    // router — exactly the anti-pattern this refactor undoes. Instead
    // listen for the side effect: notify the refresh listenable so
    // GoRouter re-evaluates its redirects in place.
    ref.listen<AuthState>(authProvider, (previous, next) {
      _routerRefresh.refresh();
      _syncFcmForAuth(previous, next);
    });
    ref.listen<bool>(onboardingProvider, (_, _) => _routerRefresh.refresh());

    // Theme rebuilds happen via MaterialApp — NOT through _RouterRefresh.
    // The router instance is intentionally preserved across theme flips.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CrewPoint',
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
