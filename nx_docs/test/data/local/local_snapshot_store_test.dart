import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/data/local/drift/drift_local_snapshot_store.dart';
import 'package:nx_docs/data/local/drift/notes_database.dart';
import 'package:nx_docs/data/local/memory/memory_local_snapshot_store.dart';

import '../../support/contracts/local_snapshot_store_contract.dart';

void main() {
  group('MemoryLocalSnapshotStore contract', () {
    runLocalSnapshotStoreContract(
      createStore: () async =>
          MemoryLocalSnapshotStore(accountKey: 'prod:user-1'),
    );
  });

  group('DriftLocalSnapshotStore contract', () {
    runLocalSnapshotStoreContract(
      createStore: () async {
        final database = NotesDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        return DriftLocalSnapshotStore(
          database: database,
          accountKey: 'prod:user-1',
        );
      },
    );
  });
}
