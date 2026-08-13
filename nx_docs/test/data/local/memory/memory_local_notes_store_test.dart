import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/application/ports/local_notes_store.dart';
import 'package:nx_docs/data/local/memory/memory_local_notes_store.dart';

import '../../../support/contracts/local_notes_store_contract.dart';

void main() {
  group('MemoryLocalNotesStore contract', () {
    runLocalNotesStoreContract(
      createStore: () async => MemoryLocalNotesStore(accountKey: 'prod:user-1'),
      disposeStore: (LocalNotesStore store) {
        return (store as MemoryLocalNotesStore).dispose();
      },
    );
  });
}
