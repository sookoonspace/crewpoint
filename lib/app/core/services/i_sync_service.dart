/// Abstract sync service for bridging local Drift DB with remote Firestore.
abstract class ISyncService {
  Future<void> syncAll();
  Future<void> syncEvents();
  Future<void> syncTasks();
  Future<void> syncMessages();
  Future<void> syncExpenses();
  Stream<SyncStatus> get syncStatusStream;
}

enum SyncStatus { idle, syncing, completed, error }
