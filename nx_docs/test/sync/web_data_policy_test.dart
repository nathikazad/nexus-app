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
