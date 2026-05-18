import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/settings_row.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('renders icon, title, optional subtitle, and chevron', (
    tester,
  ) async {
    await pump(
      tester,
      const SettingsRow(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: 'All alerts on',
      ),
    );
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('All alerts on'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('subtitle is omitted when not provided', (tester) async {
    await pump(
      tester,
      const SettingsRow(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Dashboard',
      ),
    );
    expect(find.text('Privacy Dashboard'), findsOneWidget);
    expect(find.byKey(const Key('settings.row.subtitle')), findsNothing);
  });

  testWidgets('tap fires onTap callback', (tester) async {
    var taps = 0;
    await pump(
      tester,
      SettingsRow(
        icon: Icons.attach_money,
        title: 'Currency',
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.byType(SettingsRow));
    expect(taps, 1);
  });
}
