import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_notes/data/document/document_image_assets.dart';
import 'package:nx_notes/data/document/document_schema_provider.dart';
import 'package:nx_notes/data/document/kgql_document_repository.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return KgqlDocumentRepository(
    client: ref.watch(graphqlClientProvider),
    loadDocumentSchema: () => ref.read(documentSchemaProvider.future),
    loadDocumentSnapSchema: () => ref.read(documentSnapSchemaProvider.future),
  );
});

final documentImageAssetServiceProvider = Provider<DocumentImageAssetService?>((
  ref,
) {
  final baseUrl = ref.watch(imageBaseUrlProvider);
  final userId = ref.watch(userIdProvider);
  if (baseUrl == null || userId == null) {
    return null;
  }
  final client = http.Client();
  ref.onDispose(client.close);
  return DocumentImageAssetService(
    baseUrl: baseUrl,
    userId: userId,
    client: client,
  );
});

class DocumentActiveHeading {
  const DocumentActiveHeading({
    required this.documentId,
    required this.blockIndex,
  });

  final int documentId;
  final int blockIndex;
}

final documentActiveHeadingNotifier = ValueNotifier<DocumentActiveHeading?>(
  null,
);

class DocumentHeadingScrollRequest {
  const DocumentHeadingScrollRequest({
    required this.documentId,
    required this.blockIndex,
    required this.serial,
  });

  final int documentId;
  final int blockIndex;
  final int serial;
}

final documentHeadingScrollRequestNotifier =
    ValueNotifier<DocumentHeadingScrollRequest?>(null);

void requestDocumentHeadingScroll({
  required int documentId,
  required int blockIndex,
}) {
  final nextSerial =
      (documentHeadingScrollRequestNotifier.value?.serial ?? 0) + 1;
  documentHeadingScrollRequestNotifier.value = DocumentHeadingScrollRequest(
    documentId: documentId,
    blockIndex: blockIndex,
    serial: nextSerial,
  );
}

class DocumentLocalCache extends Notifier<Map<int, NxDocument>> {
  @override
  Map<int, NxDocument> build() => const <int, NxDocument>{};

  void put(NxDocument document) {
    state = {...state, document.id: document};
  }

  void remove(int id) {
    final next = {...state};
    next.remove(id);
    state = next;
  }
}

final documentLocalCacheProvider =
    NotifierProvider<DocumentLocalCache, Map<int, NxDocument>>(
      DocumentLocalCache.new,
    );

final recentDocumentsProvider = FutureProvider<List<NxDocument>>(
  (ref) => ref.watch(documentRepositoryProvider).listRecent(limit: 20),
);

final pinnedDocumentsProvider = FutureProvider<List<NxDocument>>(
  (ref) => ref.watch(documentRepositoryProvider).listPinned(limit: 20),
);

final booksProvider = FutureProvider<List<NxDocument>>(
  (ref) => ref.watch(documentRepositoryProvider).listBooks(limit: 100),
);

final tagSystemsProvider = FutureProvider<List<TagSystem>>(
  (ref) => ref.watch(documentRepositoryProvider).listTagSystems(),
);

final documentByIdProvider = FutureProvider.family<NxDocument?, int>((ref, id) {
  final cached = ref.watch(
    documentLocalCacheProvider.select((documents) => documents[id]),
  );
  if (cached != null && cached.hasFullDocument) {
    return cached;
  }
  return ref.watch(documentRepositoryProvider).getById(id);
});

final documentSnapshotsProvider =
    FutureProvider.family<List<DocumentSnap>, int>(
      (ref, id) => ref.watch(documentRepositoryProvider).listSnapshots(id),
    );

final documentSearchProvider = FutureProvider.family<List<NxDocument>, String>(
  (ref, query) => ref.watch(documentRepositoryProvider).search(query),
);

final projectsProvider = FutureProvider<List<LinkedModel>>(
  (ref) => ref.watch(documentRepositoryProvider).listProjects(),
);

final documentsByTagProvider =
    FutureProvider.family<List<NxDocument>, DocumentTagFilter>(
      (ref, filter) => ref.watch(documentRepositoryProvider).listByTag(filter),
    );
