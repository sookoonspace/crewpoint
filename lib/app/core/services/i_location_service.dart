/// Abstract location service interface.
// TODO(phase2): Implement with Google Maps SDK for live location tracking.
abstract class ILocationService {
  Future<void> startTracking({required String eventId, required String userId});
  Future<void> stopTracking();
  Stream<LocationUpdate> get locationUpdates;
}

class LocationUpdate {
  const LocationUpdate({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
}
