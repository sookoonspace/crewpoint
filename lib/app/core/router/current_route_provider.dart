import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current `go_router` location so async handlers (e.g. the FCM
/// foreground listener) can query "are we already on chat for event X?"
/// without depending on a `BuildContext`.
///
/// The router is responsible for keeping this in sync via
/// [CurrentRouteController.set].
class CurrentRouteController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? location) {
    if (state != location) state = location;
  }
}

final currentRouteProvider = NotifierProvider<CurrentRouteController, String?>(
  CurrentRouteController.new,
);
