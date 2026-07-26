import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_notes/app.dart';
import 'package:nx_notes/application/offline_notes_service.dart';
import 'package:nx_notes/application/ports/clock.dart';
import 'package:nx_notes/application/ports/id_generator.dart';
import 'package:nx_notes/application/ports/session_store.dart';
import 'package:nx_notes/composition/offline_providers.dart';
import 'package:nx_notes/data/document/fake_document_repository.dart';
import 'package:nx_notes/data/local/memory/memory_local_notes_store.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/data/remote/unavailable/unavailable_remote_document_gateway.dart';
import 'package:nx_notes/data/session/preferences_last_opened_document_store.dart';
import 'package:nx_notes/domain/document/document_identity.dart';
import 'package:nx_notes/domain/sync/document_revision.dart';
import 'package:nx_notes/domain/sync/remote_document.dart';
import 'package:nx_notes/features/desktop/desktop_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';
import '../support/offline_sync_engine.dart';

void main() {
  testWidgets('desktop restart exposes the downloaded library offline', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    tester.platformDispatcher.textScaleFactorTestValue = 0.95;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    const session = CachedSession(
      userId: 'desktop-user',
      backendPreset: 'production',
    );
    final lastOpened = PreferencesLastOpenedDocumentStore(
      await SharedPreferences.getInstance(),
    );
    await lastOpened.save(session.accountKey, 18);

    final store = MemoryLocalNotesStore(accountKey: session.accountKey);
    final engine = createOfflineTestSyncEngine(
      localStore: store,
      remoteGateway: const UnavailableRemoteDocumentGateway(),
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    addTearDown(engine.dispose);
    addTearDown(store.dispose);
    final service = OfflineNotesService(
      localStore: store,
      syncEngine: engine,
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-17', remoteId: 17),
        document: offlineTestDocument(
          id: 17,
          title: 'Desktop restart offline',
          body: 'This desktop document came from the local database.',
        ).copyWith(jsonDocument: const <String, dynamic>{}),
        revision: const RemoteRevision('rev-17'),
      ),
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-18', remoteId: 18),
        document: offlineTestDocument(
          id: 18,
          title: 'Another persistent document',
          body: 'A second document is available without the network.',
          updatedAt: DateTime.utc(2026, 7, 20),
        ).copyWith(jsonDocument: const <String, dynamic>{}),
        revision: const RemoteRevision('rev-18'),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthController(
              initialDelay: Duration.zero,
              skipBackendPing: true,
            ),
          ),
          activeOfflineSessionProvider.overrideWith((ref) async => session),
          offlineNotesServiceProvider.overrideWithValue(service),
          documentRepositoryProvider.overrideWithValue(
            FakeDocumentRepository(),
          ),
        ],
        child: const NexusNotesApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.text('Desktop restart offline'), findsWidgets);
    expect(find.text('Another persistent document'), findsWidgets);
    expect(
      find.textContaining('second document', findRichText: true),
      findsOneWidget,
    );
  });
}

class _Clock implements Clock {
  const _Clock();

  @override
  DateTime now() => DateTime.utc(2026, 7, 21);
}

class _Ids implements IdGenerator {
  var value = 0;

  @override
  String nextId() => 'desktop-test-${value++}';
}
