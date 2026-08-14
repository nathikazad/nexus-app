import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_docs/app/docs_app.dart';
import 'package:nx_docs/sync/native/background_uploader.dart';
import 'package:nx_docs/sync/native/native_document_workspace.dart';
import 'package:nx_docs/sync/clock.dart';
import 'package:nx_docs/sync/id_generator.dart';
import 'package:nx_docs/account/account_session.dart';
import 'package:nx_docs/sync/document_synchronizer.dart';
import 'package:nx_docs/account/account_providers.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:nx_docs/sync/fake/memory_local_notes_store.dart';
import 'package:nx_docs/sync/remote/unavailable_document_remote_api.dart';
import 'package:nx_docs/workspace/preferences_last_opened_document_store.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/sync/sync_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

void main() {
  testWidgets('mobile offline restart shows the cached document library', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    const session = CachedSession(
      userId: 'user-1',
      backendPreset: 'production',
    );
    final lastOpened = PreferencesLastOpenedDocumentStore(
      await SharedPreferences.getInstance(),
    );
    await lastOpened.save(session.accountKey, 7);

    final store = MemoryLocalNotesStore(accountKey: session.accountKey);
    final uploader = BackgroundUploader(
      localStore: store,
      remoteApi: const UnavailableDocumentRemoteApi(),
      clock: const _Clock(),
      workerId: 'widget-test',
      uploadDelay: const Duration(hours: 1),
    );
    final workspace = NativeDocumentWorkspace(
      localStore: store,
      remoteApi: const UnavailableDocumentRemoteApi(),
      uploader: uploader,
      synchronizer: DocumentSynchronizer(
        localStore: store,
        remoteApi: const UnavailableDocumentRemoteApi(),
        uploader: uploader,
      ),
      clock: const _Clock(),
      idGenerator: _Ids(),
    );
    addTearDown(workspace.close);
    addTearDown(uploader.close);
    addTearDown(store.dispose);
    final cached = offlineTestDocument(
      id: 7,
      title: 'Restarted offline',
      body: 'This document came from the local database.',
    ).copyWith(jsonDocument: const <String, dynamic>{});
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-7', remoteId: 7),
        document: cached,
        revision: const RemoteRevision('rev-7'),
      ),
    ]);
    await store.replaceCatalog(const CatalogQuery.recent(), <DocumentSummary>[
      DocumentSummary.fromDocument(cached),
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
          documentWorkspaceProvider.overrideWithValue(workspace),
          backgroundUploaderProvider.overrideWithValue(uploader),
        ],
        child: const NexusDocsApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Nexus Docs'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Search documents...'), findsOneWidget);
    expect(find.text('Restarted offline'), findsOneWidget);
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
  String nextId() => 'test-${value++}';
}
