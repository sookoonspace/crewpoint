import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Links that open the app (Spec #233 Testing Strategy 5; #241): the link
/// it was launched with, then each one opened while it runs, through App
/// Links on Android and Universal Links on iOS. On the web the browser's
/// address is the route, so nothing arrives here.
abstract interface class IIncomingLinkSource {
  Stream<Uri> get links;
}

class AppLinksIncomingLinkSource implements IIncomingLinkSource {
  AppLinksIncomingLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get links {
    if (kIsWeb) return const Stream.empty();
    return Stream.multi((controller) async {
      final launch = await _appLinks.getInitialLink();
      if (launch != null) controller.add(launch);
      var skipLaunch = launch != null;
      final sub = _appLinks.uriLinkStream.listen((uri) {
        // Some platforms repeat the launch link on the stream.
        if (skipLaunch && uri == launch) {
          skipLaunch = false;
          return;
        }
        skipLaunch = false;
        controller.add(uri);
      }, onError: controller.addError);
      controller.onCancel = sub.cancel;
    });
  }
}

/// The app route a link opens, or null when it is not one the app handles:
/// invite links, event pages, personal links and email sign-in links
/// (`/auth/link`, or Firebase's `/__/auth/links`). The
/// host is not checked, since only the flavor's own domain is associated
/// with the app.
String? routeForLink(Uri uri) {
  // An email sign-in link as Firebase sends it on the Hosting domain,
  // `/__/auth/links?link=<action link>`, opening the installed app. It
  // becomes `/auth/link`, keeping the whole link for Firebase and where to
  // return from its `continueUrl`.
  if (uri.path == '/__/auth/links') {
    final link = uri.queryParameters['link'];
    if (link == null) return null;
    final action = Uri.tryParse(link);
    final next = Uri.tryParse(action?.queryParameters['continueUrl'] ?? '');
    final to = next?.queryParameters['to'];
    return Uri(
      path: '/auth/link',
      queryParameters: {'to': ?to, 'link': link},
    ).toString();
  }
  const prefixes = ['/join/', '/e/', '/r/'];
  if (!prefixes.any(uri.path.startsWith) && uri.path != '/auth/link') {
    return null;
  }
  return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
}

/// Opens each link from [source] that the app handles, through [go] (the
/// router's `go`). Cancel the subscription when the app goes.
StreamSubscription<Uri> followIncomingLinks(
  IIncomingLinkSource source,
  void Function(String location) go,
) => source.links.listen((uri) {
  final route = routeForLink(uri);
  if (route != null) go(route);
});
