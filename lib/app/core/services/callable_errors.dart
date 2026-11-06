import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// Whether a callable failed because it never reached the server, rather than
/// the server refusing it. Web reports a failed network request as `internal`.
bool isConnectionFailure(Object error) =>
    error is FirebaseFunctionsException &&
    const {'unavailable', 'deadline-exceeded', 'internal'}.contains(error.code);

/// Whether the server refused [error] for lack of permission, from a callable
/// or a Firestore rule.
bool isPermissionDenied(Object error) =>
    (error is FirebaseFunctionsException && error.code == 'permission-denied') ||
    (error is FirebaseException && error.code == 'permission-denied');

/// What to tell someone about [error], which is always logged. A refusal for
/// lack of permission gets a plain explanation, since roles can change while
/// a screen is open (#66). Anything else gets the screen's own [fallback].
String userMessageFor(
  Object error, {
  required ErrorStrings strings,
  required String fallback,
  StackTrace? stackTrace,
}) {
  log('Action failed', error: error, stackTrace: stackTrace, name: 'errors');
  return isPermissionDenied(error) ? strings.permissionDenied : fallback;
}
