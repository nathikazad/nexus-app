import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/remote/fake/fake_remote_document_gateway.dart';
import 'package:nx_notes/data/sync/nx_offline_notes_sync_engine.dart';

void main() {
  test('production composition uses the nx_offline Notes engine', () async {
    const session = CachedSession(userId: 'user-1', backendPreset: 'prod');
    final local = MemoryLocalNotesStore(accountKey: session.accountKey);
    addTearDown(local.dispose);
    final container = ProviderContainer(
      overrides: [
        activeOfflineSessionProvider.overrideWith((ref) async => session),
        localNotesStoreProvider.overrideWithValue(local),
        remoteDocumentGatewayProvider.overrideWithValue(
          FakeRemoteDocumentGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeOfflineSessionProvider.future);
    final engine = container.read(documentSyncEngineProvider);

    expect(engine, isA<NxOfflineNotesSyncEngine>());
  });
}
