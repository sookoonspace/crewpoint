/// Build flavors for CrewPoint.
enum AppFlavor {
  dev('space.sookoon.crewpoint.dev'),
  stg('space.sookoon.crewpoint.stg'),
  prod('space.sookoon.crewpoint.app');

  const AppFlavor(this.appId);

  final String appId;

  static AppFlavor fromString(String? flavor) => switch (flavor) {
    'dev' => AppFlavor.dev,
    'stg' => AppFlavor.stg,
    'prod' => AppFlavor.prod,
    _ => AppFlavor.dev,
  };
}
