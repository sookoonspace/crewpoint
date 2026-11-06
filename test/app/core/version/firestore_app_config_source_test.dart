import 'package:crewpoint_app/app/core/version/app_version_services.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads config/app, or null when it is missing', () async {
    final firestore = FakeFirebaseFirestore();
    final source = FirestoreAppConfigSource(firestore);
    expect(await source.read(), isNull);

    await firestore.doc('config/app').set({'minVersion': '1.4.0'});
    expect(await source.read(), {'minVersion': '1.4.0'});
  });
}
