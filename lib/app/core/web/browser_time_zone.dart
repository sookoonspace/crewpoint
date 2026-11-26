// The browser's IANA time zone, on the web only (#240 checks): there is no
// native code to ask, so the method channel fell back to UTC there.
export 'browser_time_zone_stub.dart'
    if (dart.library.js_interop) 'browser_time_zone_web.dart';
