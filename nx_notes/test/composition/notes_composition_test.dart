import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/application/fake/fake_notes_workspace.dart';
import 'package:nx_notes/composition/notes_composition.dart';
import 'package:nx_notes/domain/catalog/catalog_query.dart';
import 'package:nx_notes/domain/document/document.dart';

import '../support/offline_fixtures.dart';

void main() {
  test('catalog refresh does not reopen a document session', () async {
    final document = offlineTestDocument(id: 42);
    final workspace = FakeNotesWorkspace(documents: <NxDocument>[document]);
    final container = ProviderContainer(
      overrides: [notesWorkspaceProvider.overrideWithValue(workspace)],
    );
    addTearDown(() async {
      container.dispose();
      await workspace.close();
    });
    final documentSubscription = container.listen(
      documentSessionStateProvider(42),
      (_, _) {},
    );
    final catalogSubscription = container.listen(
      catalogStateProvider(const CatalogQuery.recent()),
      (_, _) {},
    );
    addTearDown(documentSubscription.close);
    addTearDown(catalogSubscription.close);

    await container.read(documentSessionStateProvider(42).future);
    await container.read(
      catalogStateProvider(const CatalogQuery.recent()).future,
    );
    await workspace.refreshCatalog(const CatalogQuery.recent());

    expect(workspace.openCount, 1);
    expect(workspace.sessionFor(42), isNotNull);
  });

  test('session updates flow through without provider invalidation', () async {
    final original = offlineTestDocument(id: 7, body: 'cached');
    final refreshed = original.copyWith(document: 'remote');
    final workspace = FakeNotesWorkspace(documents: <NxDocument>[original]);
    final container = ProviderContainer(
      overrides: [notesWorkspaceProvider.overrideWithValue(workspace)],
    );
    addTearDown(() async {
      container.dispose();
      await workspace.close();
    });
    final documents = <NxDocument?>[];
    final subscription = container.listen(offlineDocumentProvider(7), (
      _,
      next,
    ) {
      if (next.hasValue) documents.add(next.value);
    });
    addTearDown(subscription.close);

    await container.read(offlineDocumentProvider(7).future);
    workspace.sessionFor(7)!.replaceDocument(refreshed);
    await Future<void>.delayed(Duration.zero);

    expect(documents.last!.document, 'remote');
    expect(workspace.openCount, 1);
  });
}
