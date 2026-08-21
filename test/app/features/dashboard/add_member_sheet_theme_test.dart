import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart';

const _codeKey = Key('dashboard.invite.code');
const _code = 'ZUPQ8D';

/// Pumps the sheet under [theme] with the callable stubbed, so no Firebase
/// call is made. Returns once the code has rendered.
Future<void> _pumpSheet(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: AddMemberSheet(eventId: 'e1', generateInviteCode: _stubGenerate),
      ),
    ),
  );
  // initState kicks off the async generate; let it resolve and rebuild.
  await tester.pump();
  await tester.pump();
}

Future<String?> _stubGenerate(String eventId) async => _code;

/// The rounded box the code is painted on — the nearest ancestor
/// [Container] with a [BoxDecoration].
BoxDecoration _codeBoxDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.byKey(_codeKey), matching: find.byType(Container))
        .first,
  );
  return container.decoration! as BoxDecoration;
}

Color _codeColor(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_codeKey)).style!.color!;

void main() {
  group('AddMemberSheet invite code is legible', () {
    // Regression test for #34: the box hardcoded AppColors.offWhite while the
    // text took colorScheme.onSurface, so in dark mode the code was painted
    // near-white on near-white and the box looked empty. The code was present
    // and copyable the whole time, which is why no find-by-key test caught it.
    testWidgets('code colour differs from its box in dark mode', (
      tester,
    ) async {
      await _pumpSheet(tester, AppTheme.dark());

      expect(find.text(_code), findsOneWidget);
      expect(_codeColor(tester), isNot(_codeBoxDecoration(tester).color));
    });

    testWidgets('code colour differs from its box in light mode', (
      tester,
    ) async {
      await _pumpSheet(tester, AppTheme.light());

      expect(find.text(_code), findsOneWidget);
      expect(_codeColor(tester), isNot(_codeBoxDecoration(tester).color));
    });

    testWidgets('both colours are drawn from the active scheme', (
      tester,
    ) async {
      final dark = AppTheme.dark();
      await _pumpSheet(tester, dark);

      // The specific pairing matters: reading one from the theme and pinning
      // the other to a palette constant is what caused #34.
      expect(_codeColor(tester), dark.colorScheme.onSurface);
      expect(
        _codeBoxDecoration(tester).color,
        dark.colorScheme.surfaceContainerHighest,
      );
    });
  });
}
