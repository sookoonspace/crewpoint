import 'package:web/web.dart' as web;

/// Removes `#cp-ssr`, the small page `eventPageHtml` renders for
/// `/e/:eventSlug` so the event shows before the app loads (Spec #233 Req
/// 69). Once the app has drawn, it takes over.
void removeServerRenderedPage() =>
    web.document.getElementById('cp-ssr')?.remove();
