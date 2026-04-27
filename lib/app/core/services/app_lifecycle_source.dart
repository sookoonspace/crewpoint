import 'dart:async';

import 'package:flutter/widgets.dart';

/// Test seam exposing app lifecycle state changes as a broadcast stream.
///
/// In production, [WidgetsAppLifecycleSource] subscribes to the platform via
/// [WidgetsBindingObserver]. Tests can pump synthetic events into a
/// [FakeAppLifecycleSource].
abstract class AppLifecycleSource {
  Stream<AppLifecycleState> get stream;
  void dispose();
}

class WidgetsAppLifecycleSource extends WidgetsBindingObserver
    implements AppLifecycleSource {
  WidgetsAppLifecycleSource() {
    WidgetsBinding.instance.addObserver(this);
  }

  final StreamController<AppLifecycleState> _controller =
      StreamController.broadcast();

  @override
  Stream<AppLifecycleState> get stream => _controller.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.add(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }
}

/// Test-only fake. Pump events with [emit].
class FakeAppLifecycleSource implements AppLifecycleSource {
  final StreamController<AppLifecycleState> _controller =
      StreamController.broadcast();

  void emit(AppLifecycleState state) => _controller.add(state);

  @override
  Stream<AppLifecycleState> get stream => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}
