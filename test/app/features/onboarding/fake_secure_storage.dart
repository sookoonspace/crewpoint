import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';

class FakeSecureStorage extends SecureStorageService {
  FakeSecureStorage() : super(storage: null);

  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    data.clear();
  }
}
