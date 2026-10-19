import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/documents/document_models.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/library/models/catalog_state.dart';
import 'package:nx_docs/tags/tag_system.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';

final catalogStateProvider = StreamProvider.autoDispose
    .family<CatalogState, CatalogQuery>((ref, query) {
      final workspace = ref.watch(documentWorkspaceProvider);
      if (workspace == null) {
        return Stream<CatalogState>.value(const CatalogState());
      }
      return workspace.watchCatalog(query);
    });

typedef LibraryRefresh = Future<void> Function();

final libraryRefreshProvider = Provider<LibraryRefresh>((ref) {
  return () async {
    final workspace = ref.read(documentWorkspaceProvider);
    if (workspace == null) throw StateError('Notes are not ready yet.');
    await workspace.syncLibrary();
  };
});

final offlineAllDocumentsProvider =
    StreamProvider.autoDispose<List<NxDocument>>((ref) {
      return _watchDocuments(
        ref,
        const CatalogQuery.all(),
        excludeJournals: true,
      );
    });

final offlineRecentDocumentsProvider =
    StreamProvider.autoDispose<List<NxDocument>>((ref) {
      return _watchDocuments(
        ref,
        const CatalogQuery.recent(),
        excludeJournals: true,
      );
    });

final offlinePinnedDocumentsProvider =
    StreamProvider.autoDispose<List<NxDocument>>((ref) {
      return _watchDocuments(
        ref,
        const CatalogQuery.pinned(),
        excludeJournals: true,
      );
    });

final offlineBooksProvider = StreamProvider.autoDispose<List<NxDocument>>((
  ref,
) {
  return _watchDocuments(ref, const CatalogQuery.books());
});

final offlineDocumentSearchProvider = StreamProvider.autoDispose
    .family<List<NxDocument>, String>((ref, searchText) {
      if (searchText.trim().isEmpty) {
        return Stream<List<NxDocument>>.value(const <NxDocument>[]);
      }
      return _watchDocuments(
        ref,
        CatalogQuery.search(searchText),
        excludeJournals: true,
      );
    });

final offlineTagSystemsProvider = StreamProvider.autoDispose<List<TagSystem>>((
  ref,
) {
  return _watchDocuments(
    ref,
    const CatalogQuery.all(),
  ).map(tagSystemsFromDocuments);
});

Stream<List<NxDocument>> _watchDocuments(
  Ref ref,
  CatalogQuery query, {
  bool excludeJournals = false,
}) {
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) {
    return Stream<List<NxDocument>>.value(const <NxDocument>[]);
  }
  return workspace
      .watchCatalog(query)
      .map(
        (state) => state.items
            .where((summary) => !excludeJournals || !summary.isJournalEntry)
            .map((summary) => summary.toDocument())
            .toList(growable: false),
      );
}
