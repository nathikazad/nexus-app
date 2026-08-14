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

final offlineAllDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.all());
});

final offlineRecentDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.recent());
});

final offlinePinnedDocumentsProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.pinned());
});

final offlineBooksProvider = StreamProvider<List<NxDocument>>((ref) {
  return _watchDocuments(ref, const CatalogQuery.books());
});

final offlineDocumentSearchProvider =
    StreamProvider.family<List<NxDocument>, String>((ref, searchText) {
      if (searchText.trim().isEmpty) {
        return Stream<List<NxDocument>>.value(const <NxDocument>[]);
      }
      return _watchDocuments(ref, CatalogQuery.search(searchText));
    });

final offlineTagSystemsProvider = StreamProvider<List<TagSystem>>((ref) {
  return _watchDocuments(
    ref,
    const CatalogQuery.all(),
  ).map(tagSystemsFromDocuments);
});

Stream<List<NxDocument>> _watchDocuments(Ref ref, CatalogQuery query) {
  final workspace = ref.watch(documentWorkspaceProvider);
  if (workspace == null) {
    return Stream<List<NxDocument>>.value(const <NxDocument>[]);
  }
  return workspace
      .watchCatalog(query)
      .map(
        (state) => state.items
            .map((summary) => summary.toDocument())
            .toList(growable: false),
      );
}
