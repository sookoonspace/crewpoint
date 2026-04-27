import 'package:url_launcher/url_launcher.dart';

/// Test seam wrapping `package:url_launcher`. Tests fake this to avoid
/// platform calls.
abstract class IUrlLauncher {
  /// Launches [uri] in an external app. Returns true on success.
  Future<bool> launch(Uri uri);
}

class UrlLauncherService implements IUrlLauncher {
  const UrlLauncherService();

  @override
  Future<bool> launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
