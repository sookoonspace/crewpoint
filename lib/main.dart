import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Check persisted onboarding status on startup
    Future.microtask(
      () => ref.read(onboardingProvider.notifier).checkOnboardingStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnboardingComplete = ref.watch(onboardingProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState is Authenticated;

    final router = createRouter(
      isOnboardingComplete: isOnboardingComplete,
      isAuthenticated: isAuthenticated,
      onRouteChanged: (location) =>
          ref.read(currentRouteProvider.notifier).set(location),
    );

    return MaterialApp.router(
      title: 'CrewPoint',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
