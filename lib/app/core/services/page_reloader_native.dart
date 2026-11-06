import 'package:crewpoint_app/app/core/services/page_reloader.dart';

class NativePageReloader implements IPageReloader {
  const NativePageReloader();

  @override
  void reload() {}
}

IPageReloader createPageReloader() => const NativePageReloader();
