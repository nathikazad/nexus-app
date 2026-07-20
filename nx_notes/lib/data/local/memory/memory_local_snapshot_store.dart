import 'package:nx_notes/application/ports/local_snapshot_store.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/local_snapshot.dart';

class MemoryLocalSnapshotStore implements LocalSnapshotStore {
  MemoryLocalSnapshotStore({required this.accountKey});

  @override
  final String accountKey;
  final Map<String, LocalSnapshot> _snapshots = <String, LocalSnapshot>{};

  @override
  Future<void> save(LocalSnapshot snapshot) async {
    if (snapshot.accountKey != accountKey) {
      throw StateError('snapshot belongs to a different account');
    }
    _snapshots[snapshot.snapshotId] = snapshot;
  }

  @override
  Future<List<LocalSnapshot>> list(DocumentKey documentKey) async {
    return _snapshots.values
        .where((snapshot) => snapshot.documentKey == documentKey)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
