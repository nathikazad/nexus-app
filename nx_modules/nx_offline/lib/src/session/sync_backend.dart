import 'package:nx_data/nx_data.dart';
import 'package:nx_sync/nx_sync.dart';

/// Adapts domain-specific durable reconcilers to the shared app session.
final class PersistentSyncBackend implements OfflineSyncBackend {
  const PersistentSyncBackend(this.reconcile);
  final Future<void> Function(SyncReason reason) reconcile;
  @override
  Future<void> synchronize(SyncReason reason) => reconcile(reason);
}
