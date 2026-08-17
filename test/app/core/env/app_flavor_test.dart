import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';

/// Guards the flavor-resolution contract that keeps
/// `flutter run --flavor stg` correct without a matching
/// `--dart-define=FLAVOR=`.
///
/// The native package identifier is the source of truth on iOS and
/// Android. Getting this wrong is expensive and invisible: the app boots
/// against the wrong Firebase project, or — before this resolution
/// existed — died with `[core/duplicate-app]` and a blank screen.
void main() {
  tearDown(AppFlavor.resetResolvedFlavor);

  group('fromAppId', () {
    test('maps each flavor package id back to its flavor', () {
      for (final flavor in AppFlavor.values) {
        expect(
          AppFlavor.fromAppId(flavor.appId),
          equals(flavor),
          reason: '${flavor.appId} should resolve to ${flavor.name}',
        );
      }
    });

    test('returns null for an id this app does not own', () {
      expect(AppFlavor.fromAppId('com.example.other'), isNull);
      expect(AppFlavor.fromAppId(''), isNull);
      expect(AppFlavor.fromAppId(null), isNull);
    });

    test('does not match on prefix — ids must be exact', () {
      // `space.sookoon.crewpoint` is a prefix of all three real ids; a
      // substring match here would silently pick the wrong project.
      expect(AppFlavor.fromAppId('space.sookoon.crewpoint'), isNull);
      expect(AppFlavor.fromAppId('space.sookoon.crewpoint.dev.debug'), isNull);
    });

    test('every flavor has a distinct app id', () {
      final ids = AppFlavor.values.map((f) => f.appId).toSet();
      expect(ids, hasLength(AppFlavor.values.length));
    });
  });

  group('resolveFromNativeAppId', () {
    test('adopts the flavor owning the package id', () {
      AppFlavor.resolveFromNativeAppId(AppFlavor.stg.appId);
      expect(AppFlavor.current, equals(AppFlavor.stg));

      AppFlavor.resolveFromNativeAppId(AppFlavor.prod.appId);
      expect(AppFlavor.current, equals(AppFlavor.prod));
    });

    test('leaves the define fallback in place for an unknown id', () {
      // A renamed bundle must not brick startup; `main` reports the
      // genuine contradiction separately.
      AppFlavor.resolveFromNativeAppId('com.example.other');
      expect(AppFlavor.current, equals(AppFlavor.fromDefine));
    });
  });

  group('current', () {
    test('falls back to the define when nothing is resolved', () {
      // This is the web and `flutter test` path — neither runs the
      // native resolution step.
      expect(AppFlavor.current, equals(AppFlavor.fromDefine));
    });

    test('under flutter test the define is absent, so dev', () {
      expect(AppFlavor.fromDefine, equals(AppFlavor.dev));
      expect(AppFlavor.current, equals(AppFlavor.dev));
    });
  });

  group('fromString', () {
    test('maps known names and defaults unknown input to dev', () {
      expect(AppFlavor.fromString('dev'), equals(AppFlavor.dev));
      expect(AppFlavor.fromString('stg'), equals(AppFlavor.stg));
      expect(AppFlavor.fromString('prod'), equals(AppFlavor.prod));
      expect(AppFlavor.fromString('nonsense'), equals(AppFlavor.dev));
      expect(AppFlavor.fromString(null), equals(AppFlavor.dev));
    });
  });

  group('legalBaseUrl', () {
    test('prod uses the custom domain, never *.web.app', () {
      expect(AppFlavor.prod.legalBaseUrl, isNot(contains('web.app')));
      expect(AppFlavor.dev.legalBaseUrl, contains('crewpoint-dev'));
      expect(AppFlavor.stg.legalBaseUrl, contains('crewpoint-stg'));
    });
  });
}
