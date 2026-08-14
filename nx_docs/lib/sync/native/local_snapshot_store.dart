import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';

abstract interface class LocalSnapshotStore {
  String get accountKey;

  Future<void> save(LocalSnapshot snapshot);

  Future<List<LocalSnapshot>> list(DocumentKey documentKey);
}
