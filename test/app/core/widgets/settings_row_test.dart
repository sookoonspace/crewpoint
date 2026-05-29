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

  testWidgets('custom `trailing` widget replaces the default chevron', (
    tester,
  ) async {
    const trailingKey = Key('settings.row.test.trailing');
    await pump(
      tester,
      const SettingsRow(
        icon: Icons.brightness_6_outlined,
        title: 'Theme',
        trailing: Text('Dark', key: trailingKey),
      ),
    );

    expect(find.byKey(trailingKey), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets(
    'leading icon + title + subtitle + chevron all resolve from colorScheme',
    (tester) async {
      // Sentinel colors injected into the ColorScheme so the assertions
      // can't accidentally match defaults (or the legacy AppColors.*).
      const onSurfaceSentinel = Color(0xFFAA00AA);
      const onSurfaceVariantSentinel = Color(0xFF00AABB);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(
              onSurface: onSurfaceSentinel,
              onSurfaceVariant: onSurfaceVariantSentinel,
            ),
          ),
          home: const Scaffold(
            body: SettingsRow(
              icon: Icons.brightness_6_outlined,
              title: 'Theme',
              subtitle: 'Follow device',
            ),
          ),
        ),
      );

      // Leading icon: onSurface.
      final leadingIcon = tester.widget<Icon>(
        find.byIcon(Icons.brightness_6_outlined),
      );
      expect(leadingIcon.color, onSurfaceSentinel);

      // Default trailing chevron: onSurfaceVariant.
      final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(chevron.color, onSurfaceVariantSentinel);

      // Title text: onSurface.
      final titleText = tester.widget<Text>(find.text('Theme'));
      expect(titleText.style?.color, onSurfaceSentinel);

      // Subtitle text: onSurfaceVariant (keyed).
      final subtitleText = tester.widget<Text>(
        find.byKey(const Key('settings.row.subtitle')),
      );
      expect(subtitleText.style?.color, onSurfaceVariantSentinel);
    },
  );
}
