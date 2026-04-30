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

  /// Active flavor resolved from `--dart-define=FLAVOR=...`. Defaults
  /// to `dev` if the define is missing (typical for `flutter test` and
  /// `flutter run` without an explicit flavor flag).
  static final AppFlavor current = AppFlavor.fromString(
    const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
  );
}
