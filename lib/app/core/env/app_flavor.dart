/// Build flavors for CrewPoint.
enum AppFlavor {
  dev(
    appId: 'space.sookoon.crewpoint.dev',
    legalBaseUrl: 'https://crewpoint-dev.web.app',
  ),
  stg(
    appId: 'space.sookoon.crewpoint.stg',
    legalBaseUrl: 'https://crewpoint-stg.web.app',
  ),
  prod(
    appId: 'space.sookoon.crewpoint.app',
    legalBaseUrl: 'https://crewpoint.sookoon.space',
  );

  const AppFlavor({required this.appId, required this.legalBaseUrl});

  final String appId;

  /// Base URL for the hosted Privacy Policy + Terms of Service pages.
  /// Auth-gate footer + `MarkdownRenderScreen`'s "View hosted version"
  /// link consume this. Production builds resolve to the custom domain
  /// `crewpoint.sookoon.space`, never `*.web.app`.
  final String legalBaseUrl;

  static AppFlavor fromString(String? flavor) => switch (flavor) {
    'dev' => AppFlavor.dev,
    'stg' => AppFlavor.stg,
    'prod' => AppFlavor.prod,
    _ => AppFlavor.dev,
  };

  /// Reverse of [appId] — resolves a native package / bundle identifier
  /// back to its flavor. Returns null for an id this app does not own.
  static AppFlavor? fromAppId(String? appId) {
    for (final flavor in AppFlavor.values) {
      if (flavor.appId == appId) return flavor;
    }
    return null;
  }

  /// The flavor named by `--dart-define=FLAVOR=...`, defaulting to `dev`.
  ///
  /// This is only the *fallback*. On iOS and Android the native package
  /// identifier is authoritative — see [resolveFromNativeAppId].
  static final AppFlavor fromDefine = AppFlavor.fromString(
    const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
  );

  static AppFlavor? _resolved;

  /// Active flavor.
  ///
  /// On iOS and Android this is derived from the native package identifier,
  /// which `--flavor` already selects — so `flutter run --flavor stg` is
  /// correct on its own and `--dart-define=FLAVOR=` is not required.
  ///
  /// Falls back to [fromDefine] when nothing has been resolved: on web,
  /// which has no native build to select and where the define is therefore
  /// the only selector, and under `flutter test`, which never runs `main`.
  static AppFlavor get current => _resolved ?? fromDefine;

  /// Adopts the flavor that owns [packageName], the native package or
  /// bundle identifier reported by `PackageInfo.fromPlatform()`.
  ///
  /// Called once from `main` before `runApp`. Every read of [current]
  /// happens during widget build or later, so no caller can observe the
  /// pre-resolution value.
  ///
  /// An unrecognised id leaves the fallback in place rather than throwing:
  /// a renamed bundle should not brick startup, and `main`'s explicit
  /// mismatch check is what surfaces a genuine contradiction.
  static void resolveFromNativeAppId(String packageName) {
    _resolved = AppFlavor.fromAppId(packageName);
  }

  /// Clears the resolved flavor. Tests only.
  static void resetResolvedFlavor() => _resolved = null;
}
