import 'dart:async';

import 'package:crewpoint_app/app/core/services/incoming_links.dart';

/// Links "opened" on demand (#241): [open] pushes one, as App Links or
/// Universal Links would.
class FakeIncomingLinkSource implements IIncomingLinkSource {
  final _controller = StreamController<Uri>.broadcast();

  void open(String link) => _controller.add(Uri.parse(link));

  @override
  Stream<Uri> get links => _controller.stream;

  Future<void> close() => _controller.close();
}
