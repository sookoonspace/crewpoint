import 'package:cloud_functions/cloud_functions.dart';

/// Whether a callable failed because it never reached the server, rather than
/// the server refusing it. Web reports a failed network request as `internal`.
bool isConnectionFailure(Object error) =>
    error is FirebaseFunctionsException &&
    const {'unavailable', 'deadline-exceeded', 'internal'}.contains(error.code);
