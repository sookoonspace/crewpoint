import 'package:crewpoint_app/app/core/services/page_reloader.dart';
import 'package:web/web.dart' as web;

class WebPageReloader implements IPageReloader {
  const WebPageReloader();

  @override
  void reload() => web.window.location.reload();
}

IPageReloader createPageReloader() => const WebPageReloader();
