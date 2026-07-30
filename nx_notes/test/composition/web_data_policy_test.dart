import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/web/web_notes_workspace.dart';
import 'package:nx_notes/composition/notes_composition.dart';
import 'package:nx_notes/data/remote/fake/fake_notes_remote_api.dart';
import 'package:nx_notes/domain/document/document.dart';

import '../support/offline_fixtures.dart';

void main() {
  test('web composition creates no SQLite store or uploader', () {
    final remote = FakeNotesRemoteApi(
      documents: <NxDocument>[offlineTestDocument()],
    );
    final container = ProviderContainer(
      overrides: [
        offlineEnabledProvider.overrideWithValue(false),
        notesRemoteApiProvider.overrideWithValue(remote),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(localNotesStoreProvider), isNull);
    expect(container.read(backgroundUploaderProvider), isNull);
    expect(container.read(notesWorkspaceProvider), isA<WebNotesWorkspace>());
  });

  test('web provider rebuilds share one open document session', () async {
    final remote = FakeNotesRemoteApi(
      documents: <NxDocument>[offlineTestDocument(id: 4)],
    );
    final container = ProviderContainer(
      overrides: [
        offlineEnabledProvider.overrideWithValue(false),
        notesRemoteApiProvider.overrideWithValue(remote),
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
