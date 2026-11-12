import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/crash_reporter.dart';
import 'package:crewpoint_app/app/features/dev/presentation/dev_tools_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingReporter implements ICrashReporter {
  _RecordingReporter({required this.isOn});

  @override
  final bool isOn;
  final reports = <Object>[];

  @override
  Future<String?> report(Object error, StackTrace stackTrace) async {
    reports.add(error);
    return 'abc123';
  }

  @override
  void setRoute(String location) {}
}

Widget _app(ICrashReporter reporter) => ProviderScope(
  overrides: [
    crashReporterProvider.overrideWithValue(reporter),
    currentUserIdProvider.overrideWithValue(null),
  ],
  child: const MaterialApp(home: DevToolsScreen()),
);

void main() {
  testWidgets('sends a test report and shows its ID', (tester) async {
    final reporter = _RecordingReporter(isOn: true);
    await tester.pumpWidget(_app(reporter));

    await tester.tap(find.byKey(const Key('dev.crash.report')));
    await tester.pump();

    expect(reporter.reports.single, isA<StateError>());
    expect(find.textContaining('abc123'), findsOneWidget);
  });

  testWidgets('says when crash reporting is off', (tester) async {
    await tester.pumpWidget(_app(_RecordingReporter(isOn: false)));

    expect(find.byKey(const Key('dev.crash.off')), findsOneWidget);
    expect(find.byKey(const Key('dev.crash.report')), findsNothing);
  });
}
