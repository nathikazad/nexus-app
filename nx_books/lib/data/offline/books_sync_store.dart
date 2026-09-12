import 'dart:convert';

import 'package:nx_db/documents.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_documents/nx_documents.dart';
import 'package:nx_offline/nx_offline_storage.dart';
import '../../domain/book/book.dart';
import '../../domain/book/reading_history.dart';
import '../../domain/book/reading_history_codec.dart';
import '../book/kgql_book_repository.dart';
import 'cached_book_repository.dart';
import 'cached_document_repository.dart';
import 'reading_history_store.dart';

/// Local verification and projections, independent of networking and UI.
final class BooksSyncStore {
  BooksSyncStore(this.library, this.documents, this.histories, this.catalog);
  final FileLibrary library;
  final CachedDocumentContentRepository documents;
  final ReadingHistoryStore histories;
  final CachedBookRepository catalog;

  DocumentIdentity identity(DocumentHashEntry entry) => DocumentIdentity(
    id: entry.id,
    modelType: entry.modelType == 'Book' ? 'Book' : 'Document',
  );

  String _historyKey(DocumentIdentity id) => '${id.modelType}_${id.id}';

  /// Only return results after this bounded page has committed. The caller
  /// owns paging/progress; this layer owns the local transaction and merge.
  Future<List<String>> applyBatch(
    List<DocumentSyncEntry> entries,
    int historyGeneration,
    int documentGeneration,
  ) => library.batchWrites(() async {
    final failed = <String>[];
    for (final entry in entries) {
      try {
        await apply(entry, historyGeneration, documentGeneration);
      } catch (_) {
        failed.add('${entry.documentId}');
      }
    }
    return failed;
  });

  Future<bool> verified(DocumentHashEntry entry) async {
    try {
      final id = identity(entry);
      final raw = await library.read('book_sync', '${entry.id}');
      if (raw == null) return false;
      final marker = jsonDecode(raw) as Map;
      if (marker['hash'] != entry.hash ||
          !await documents.hasSyncedContent(id, entry.hash)) {
        return false;
      }
      final history = await library.metadata(
        'reading_history',
        _historyKey(id),
      );
      final epubReference = marker['epubHistoryReference'];
      if (epubReference != null) {
        final epubId = DocumentIdentity(id: entry.id, modelType: 'EpubBook');
        final metadata = await library.metadata(
          'reading_history',
          _historyKey(epubId),
        );
        if (metadata?.reference != epubReference ||
            await histories.load(epubId) == null) {
          return false;
        }
      }
      return history?.reference == marker['historyReference'] &&
          await histories.load(id) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> apply(
    DocumentSyncEntry entry,
    int historyGeneration,
    int documentGeneration,
  ) async {
    if (documents.generation != documentGeneration) {
      throw StateError('Document edited during sync; retry after saving');
    }
    final model = Model.fromJson(entry.document);
    final type = (entry.document['model_type'] as Map)['name'] as String;
    final id = identity(
      DocumentHashEntry(entry.documentId, type, entry.syncHash),
    );
    final transcripts = entry.document['transcripts'] as List? ?? const [];
    final history = ReadingHistory(
      model.name,
      readingMessagesFromHistory(
        transcripts.isEmpty ? null : (transcripts.first as Map)['messages'],
        limit: 100,
      ),
    );
    await documents.cacheSynced(
      documentContentFromModel(id, model),
      entry.syncHash,
    );
    if (!await histories.saveDownloaded(id, history, historyGeneration)) {
      throw StateError(
        'Conversation changed during sync; retry after it finishes',
      );
    }
    final reference = await library.metadata(
      'reading_history',
      _historyKey(id),
    );
    String? epubReference;
    final epub = entry.document['epub_transcript'];
    if (type == 'Book' && epub is Map) {
      final epubId = DocumentIdentity(
        id: entry.documentId,
        modelType: 'EpubBook',
      );
      if (!await histories.saveDownloaded(
        epubId,
        ReadingHistory(
          model.name,
          readingMessagesFromHistory(epub['messages'], limit: 100),
        ),
        historyGeneration,
      )) {
        throw StateError('EPUB conversation changed during sync; retry');
      }
      epubReference = (await library.metadata(
        'reading_history',
        _historyKey(epubId),
      ))!.reference;
    }
    // Publish the acknowledgment last. Interrupted writes are retried, never
    // advertised as current just because the HTTP request completed.
    await library.saveRemote(
      'book_sync',
      '${entry.documentId}',
      jsonEncode({
        'hash': entry.syncHash,
        'modelType': id.modelType,
        'historyReference': reference!.reference,
        if (epubReference != null) 'epubHistoryReference': epubReference,
        if (type == 'Book')
          'book': {
            ...entry.document,
            'transcripts': [],
            'epub_transcript': null,
            'relations': [],
            'attributes': {...?model.attributes}
              ..remove('document')
              ..remove('json_document'),
          },
      }),
    );
    if (!await verified(
      DocumentHashEntry(entry.documentId, type, entry.syncHash),
    )) {
      throw StateError('Saved document or conversation could not be verified');
    }
  }

  Future<void> publish(
    List<DocumentHashEntry> manifest,
    List<String> tags,
    int catalogGeneration,
  ) async {
    final books = <NxBook>[];
    for (final entry in manifest.where((e) => e.modelType == 'Book')) {
      final marker =
          jsonDecode((await library.read('book_sync', '${entry.id}'))!) as Map;
      books.add(
        bookFromModel(
          Model.fromJson(Map<String, dynamic>.from(marker['book'] as Map)),
        ),
      );
    }
    await catalog.cacheSyncedCatalog(books, tags, catalogGeneration);
    final active = manifest.map((e) => '${e.id}').toSet();
    String? after;
    while (true) {
      final page = await library.list('book_sync', after: after);
      if (page.isEmpty) break;
      for (final item in page) {
        if (active.contains(item.id)) continue;
        final raw = await library.read('book_sync', item.id);
        if (raw != null) {
          final marker = jsonDecode(raw) as Map;
          await library.removeRemote(marker['modelType'] as String, item.id);
        }
        await library.removeRemote('book_sync', item.id);
      }
      after = page.last.id;
    }
  }
}
