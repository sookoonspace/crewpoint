// The public event view that `eventPageHtml` puts in `/e/:eventSlug`'s
// first page (`#cp-event`), on the web only (#240 speed budget).
export 'embedded_event_stub.dart'
    if (dart.library.js_interop) 'embedded_event_web.dart';
