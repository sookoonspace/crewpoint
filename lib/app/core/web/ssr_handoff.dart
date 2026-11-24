// The server-rendered first page of `/e/:eventSlug` (#240) is removed once
// the app draws, on the web only.
export 'ssr_handoff_stub.dart'
    if (dart.library.js_interop) 'ssr_handoff_web.dart';
