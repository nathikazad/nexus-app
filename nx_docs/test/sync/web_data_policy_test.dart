import 'package:nx_docs/library/models/catalog_query.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/sync/web/web_document_workspace.dart';
import 'package:nx_docs/sync/sync_providers.dart';
import 'package:nx_docs/documents/document_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:nx_docs/sync/fake/fake_document_remote_api.dart';
import 'package:nx_docs/documents/document_models.dart';

import '../support/offline_fixtures.dart';

void main() {
  test(
    'web refresh fetches only observed catalogs and stops after leaving',
    () async {
      final remote = FakeDocumentRemoteApi();
      final workspace = WebDocumentWorkspace(remoteApi: remote);
      addTearDown(workspace.close);
      await workspace.syncLibrary();
      expect(remote.catalogFetchCount, 0);
      final loaded = Completer<void>();
      final subscription = workspace
          .watchCatalog(const CatalogQuery.recent())
          .listen((state) {
            if (!state.isInitialLoading && !loaded.isCompleted) {
              loaded.complete();
            }
          });
      await loaded.future;
      expect(remote.catalogFetchCount, 1);
      await workspace.syncLibrary();
      expect(remote.catalogFetchCount, 2);
      await subscription.cancel();
      await workspace.syncLibrary();
      expect(remote.catalogFetchCount, 2);
      expect(remote.syncCount, 0);
      expect(remote.documentFetchCounts, isEmpty);
    },
  );

  test(
    'web sync refreshes open documents but preserves a racing draft',
    () async {
      final remote = FakeDocumentRemoteApi(
        documents: [offlineTestDocument(id: 4)],
      );
      final workspace = WebDocumentWorkspace(remoteApi: remote);
      addTearDown(workspace.close);
      final session = workspace.openDocument(4);
      await session.refresh();
      remote.replaceRemote(
        offlineTestDocument(id: 4, title: 'From another device'),
      );
      await workspace.syncLibrary();
      expect(session.state.document!.title, 'From another device');
      final download = Completer<void>();
      final upload = Completer<void>();
      remote.documentBarrier = download.future;
      remote.saveBarrier = upload.future;
      final refresh = session.refresh();
      final save = session.saveDraft(
        offlineTestDocument(id: 4, title: 'My new draft'),
      );
      download.complete();
      await refresh;
      expect(session.state.document!.title, 'My new draft');
      upload.complete();
      await save;
    },
  );

  test('web composition creates no SQLite store or uploader', () {
    final remote = FakeDocumentRemoteApi(
      documents: <NxDocument>[offlineTestDocument()],
    );
    final container = ProviderContainer(
      overrides: [
        offlineEnabledProvider.overrideWithValue(false),
        documentRemoteApiProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(localNotesStoreProvider), isNull);
    expect(container.read(backgroundUploaderProvider), isNull);
    expect(
      container.read(documentWorkspaceProvider),
      isA<WebDocumentWorkspace>(),
    );
  });

  test('web provider rebuilds share one open document session', () async {
    final remote = FakeDocumentRemoteApi(
      documents: <NxDocument>[offlineTestDocument(id: 4)],
    );
    final container = ProviderContainer(
      overrides: [
        offlineEnabledProvider.overrideWithValue(false),
        documentRemoteApiProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      documentSessionStateProvider(4),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container.read(documentSessionStateProvider(4).future);
    container.read(documentSessionProvider(4));
    container.read(documentSessionProvider(4));

    expect(remote.documentFetchCounts[4], 1);
  });
}
