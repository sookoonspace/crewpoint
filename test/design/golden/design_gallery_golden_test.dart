@Tags(['design'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/gallery/design_gallery.dart';

import '_fonts.dart';

/// Golden pictures of the Design gallery, one per section and variant
/// (Spec #186 Req 17, ledger L15). Generated and compared on Linux only:
/// `dart_test.yaml` skips the `design` tag locally, CI runs it on every PR,
/// and `.github/workflows/design-goldens.yml` regenerates the images.
/// The same pictures illustrate `docs/design/design-system.md`.
void main() {
  setUpAll(loadDesignFonts);

  for (final variant in DesignGalleryVariant.values) {
    for (final section in DesignGallerySection.values) {
      testWidgets('${section.name} · ${variant.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: DesignGalleryFrame(
              variant: variant,
              child: Align(
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: const Key('golden'),
                  child: DesignGalleryFrame(
                    variant: variant,
                    child: DesignGallery(sections: [section]),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await expectLater(
          find.byKey(const Key('golden')),
          matchesGoldenFile('goldens/${section.name}-${variant.name}.png'),
        );
      });
    }
  }
}
