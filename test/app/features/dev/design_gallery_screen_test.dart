import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/gallery/design_gallery.dart';
import 'package:crewpoint_app/app/core/design/theme/cp_theme.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/features/dev/presentation/design_gallery_screen.dart';

void main() {
  Future<void> pumpGallery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: CpTheme.light(), home: const DesignGalleryScreen()),
    );
  }

  Color firstCardColour(WidgetTester tester) => tester
      .widget<Material>(
        find
            .descendant(
              of: find.byType(CpCard),
              matching: find.byType(Material),
            )
            .first,
      )
      .color!;

  testWidgets('shows every section of the gallery', (tester) async {
    await pumpGallery(tester);
    for (final section in DesignGallerySection.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('dev.gallery.${section.name}')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(Key('dev.gallery.${section.name}')),
        findsOneWidget,
        reason: section.name,
      );
    }
  });

  testWidgets('switches between light, dark and 200% text', (tester) async {
    await pumpGallery(tester);
    expect(firstCardColour(tester), CpColors.light.surface);

    await tester.tap(find.byKey(const Key('dev.gallery.dark')));
    await tester.pump();
    expect(firstCardColour(tester), CpColors.dark.surface);

    await tester.tap(find.byKey(const Key('dev.gallery.largeText')));
    await tester.pump();
    expect(firstCardColour(tester), CpColors.light.surface);
    final scale = MediaQuery.textScalerOf(
      tester.element(find.byType(DesignGallery)),
    );
    expect(scale.scale(10), 20);
  });
}
