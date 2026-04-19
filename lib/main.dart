import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // For now, start unauthenticated with onboarding complete.
    // Real state will come from auth/onboarding providers once Firebase is configured.
    final router = createRouter(
      isOnboardingComplete: true,
      isAuthenticated: false,
    );

    return MaterialApp.router(
      title: 'CrewPoint',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
