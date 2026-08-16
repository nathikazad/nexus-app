import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/riverpod.dart';
import 'package:nx_docs/documents/assets/document_image_assets.dart';
import 'package:nx_docs/documents/data/kgql/document_schema_provider.dart';
import 'package:nx_docs/documents/data/kgql/kgql_document_repository.dart';
import 'package:nx_docs/documents/data/kgql/nx_docs_state.dart';
import 'package:nx_docs/documents/document_repository.dart';
import 'package:nx_docs/documents/document_models.dart';

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
  final user = ref.watch(authProvider).value;
  if (user == null) {
    return null;
  }
  final imageBaseUrl = resolve(user.preset).imageHttp;
  debugPrint(
    '[nx_docs image] connector preset=${user.preset.key} '
    'image_base=$imageBaseUrl app_base=${Uri.base}',
  );
  final client = ref.watch(nexusHttpClientProvider);
  if (client == null) return null;
  return DocumentImageAssetService(
    baseUrl: imageBaseUrl,
    userId: user.userId,
    client: client,
  );
});

final nxDocsStateServiceProvider = Provider<NxDocsStateService?>((ref) {
  final user = ref.watch(authProvider).value;
  if (user == null) {
    return null;
  }
  final client = ref.watch(nexusHttpClientProvider);
  if (client == null) return null;
  return NxDocsStateService(
    baseUrl: resolve(user.preset).imageHttp,
    userId: user.userId,
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

final documentSnapshotsProvider =
    FutureProvider.family<List<DocumentSnap>, int>(
      (ref, id) => ref.watch(documentRepositoryProvider).listSnapshots(id),
    );

final projectsProvider = FutureProvider<List<LinkedModel>>(
  (ref) => ref.watch(documentRepositoryProvider).listProjects(),
);
