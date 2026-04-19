import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Lists all third-party dependencies used by the app.
class PrivacyDashboardScreen extends StatelessWidget {
  const PrivacyDashboardScreen({super.key});

  static const _dependencies = [
    ('Firebase Auth', 'Authentication services'),
    ('Cloud Firestore', 'Real-time database'),
    ('Firebase Storage', 'File storage'),
    ('Google Sign-In', 'Social authentication'),
    ('Sign in with Apple', 'Social authentication'),
    ('Drift (SQLite)', 'Local offline database'),
    ('Google Fonts', 'Typography'),
    ('Flutter Secure Storage', 'Encrypted local storage'),
    ('Image Picker', 'Camera/gallery access'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Dashboard')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.xl),
        itemCount: _dependencies.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (_, index) {
          final (name, purpose) = _dependencies[index];
          return ListTile(
            title: Text(name),
            subtitle: Text(purpose),
            leading: const Icon(Icons.extension),
          );
        },
      ),
    );
  }
}
