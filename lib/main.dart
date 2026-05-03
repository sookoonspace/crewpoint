import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/router/current_route_provider.dart';
import 'package:crewpoint_app/app/core/services/firebase_service.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const ProviderScope(child: MyApp()));
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
  }

  @override
  void dispose() {
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
    ref.listen<AuthState>(authProvider, (_, _) => _routerRefresh.refresh());
    ref.listen<bool>(onboardingProvider, (_, _) => _routerRefresh.refresh());

    return MaterialApp.router(
      title: 'CrewPoint',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
