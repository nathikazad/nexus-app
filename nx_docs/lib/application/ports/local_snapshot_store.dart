import 'package:nx_docs/domain/document/document_identity.dart';
import 'package:nx_docs/domain/sync/local_snapshot.dart';

abstract interface class LocalSnapshotStore {
  String get accountKey;

  Future<void> save(LocalSnapshot snapshot);

  Future<List<LocalSnapshot>> list(DocumentKey documentKey);
}
