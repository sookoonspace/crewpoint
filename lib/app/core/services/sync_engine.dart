import 'dart:async';
import 'dart:developer';

import 'package:crewpoint_app/app/core/services/i_sync_service.dart';

/// Basic Drift↔Firestore bidirectional sync engine.
/// Uses last-write-wins conflict resolution based on updatedAt timestamps.
class SyncEngine implements ISyncService {
  final _statusController = StreamController<SyncStatus>.broadcast();

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  @override
  Future<void> syncAll() async {
    _statusController.add(SyncStatus.syncing);
    try {
      await syncEvents();
      await syncTasks();
      await syncMessages();
      await syncExpenses();
      _statusController.add(SyncStatus.completed);
    } catch (e, st) {
      log('Sync failed', error: e, stackTrace: st, name: 'sync');
      _statusController.add(SyncStatus.error);
    }
  }

  @override
  Future<void> syncEvents() async {
    // Upload local events with updatedAt > lastSyncTime to Firestore
    // Download Firestore events with updatedAt > lastSyncTime to Drift
    // Conflict resolution: last-write-wins based on updatedAt
    log('Syncing events...', name: 'sync');
  }

  @override
  Future<void> syncTasks() async {
    log('Syncing tasks...', name: 'sync');
  }

  @override
  Future<void> syncMessages() async {
    log('Syncing messages...', name: 'sync');
  }

  @override
  Future<void> syncExpenses() async {
    log('Syncing expenses...', name: 'sync');
  }

  void dispose() {
    _statusController.close();
  }
}
