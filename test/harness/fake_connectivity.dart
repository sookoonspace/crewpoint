import 'package:crewpoint_app/app/core/services/connectivity.dart';

/// Online unless a test turns the connection off.
class FakeConnectivity implements IConnectivity {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;
}
