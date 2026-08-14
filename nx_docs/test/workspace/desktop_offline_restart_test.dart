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
import 'package:nx_docs/workspace/desktop/desktop_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/offline_fixtures.dart';

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
    final uploader = BackgroundUploader(
      localStore: store,
      remoteApi: const UnavailableDocumentRemoteApi(),
      clock: const _Clock(),
      workerId: 'desktop-widget-test',
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
    final first = offlineTestDocument(
      id: 17,
      title: 'Desktop restart offline',
      body: 'This desktop document came from the local database.',
    ).copyWith(jsonDocument: const <String, dynamic>{});
    final second = offlineTestDocument(
      id: 18,
      title: 'Another persistent document',
      body: 'A second document is available without the network.',
      updatedAt: DateTime.utc(2026, 7, 20),
    ).copyWith(jsonDocument: const <String, dynamic>{});
    await store.importRemoteDocuments(<RemoteDocument>[
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-17', remoteId: 17),
        document: first,
        revision: const RemoteRevision('rev-17'),
      ),
      RemoteDocument(
        key: const DocumentKey(localId: 'remote-18', remoteId: 18),
        document: second,
        revision: const RemoteRevision('rev-18'),
      ),
    ]);
    await store.replaceCatalog(const CatalogQuery.recent(), <DocumentSummary>[
      DocumentSummary.fromDocument(first),
      DocumentSummary.fromDocument(second),
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

    expect(find.byType(DesktopWorkspace), findsOneWidget);
    expect(find.text('Desktop restart offline'), findsWidgets);
    expect(find.text('Another persistent document'), findsWidgets);
    await tester.tap(find.text('Another persistent document').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
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
