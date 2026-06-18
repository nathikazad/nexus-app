import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_result_context.dart';
import 'package:nx_notes/domain/document/document_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';

final documentMutationControllerProvider = Provider<DocumentMutationController>(
  DocumentMutationController.new,
);

final documentResultControllerProvider = Provider<DocumentResultController>(
  DocumentResultController.new,
);

enum DraftSavePolicy { deferred, immediate }

class DocumentMutationController {
  DocumentMutationController(this._ref) {
    _ref.onDispose(() {
      _draftFlushTimer?.cancel();
    });
  }

  final Ref _ref;
  static const Duration _draftWriteDelay = Duration(seconds: 10);
  Timer? _draftFlushTimer;
  NxDocument? _pendingDraft;
  Future<void>? _draftWriteInFlight;

  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final document = await _ref
        .read(documentRepositoryProvider)
        .create(title: title, kind: kind);
    _logDbSync('create_document', documentId: document.id);
    _cacheDocument(document);
    _ref.invalidate(recentDocumentsProvider);
    _ref.invalidate(pinnedDocumentsProvider);
    if (kind == DocumentKind.book) {
      _ref.invalidate(booksProvider);
    }
    return document;
  }

  Future<void> saveDraft(
    NxDocument document, {
    DraftSavePolicy policy = DraftSavePolicy.deferred,
  }) async {
    _pendingDraft = document.copyWith(
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _cacheDocument(_pendingDraft!);
    if (policy == DraftSavePolicy.immediate) {
      await _flushDraftNow();
      return;
    }
    _scheduleDraftWrite();
  }

  Future<void> saveNow(NxDocument fallback) async {
    _pendingDraft ??= fallback.copyWith(
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _cacheDocument(_pendingDraft!);
    await _flushDraftNow();
  }

  Future<void> deleteDocument(NxDocument document) async {
    _draftFlushTimer?.cancel();
    _draftFlushTimer = null;
    if (_draftWriteInFlight != null) {
      await _draftWriteInFlight;
    }
    _pendingDraft = null;
    await _ref.read(documentRepositoryProvider).delete(document.id);
    _logDbSync('delete_document', documentId: document.id);
    _ref.read(documentLocalCacheProvider.notifier).remove(document.id);
    _ref.invalidate(recentDocumentsProvider);
    _ref.invalidate(pinnedDocumentsProvider);
    _ref.invalidate(booksProvider);
    _ref.invalidate(tagSystemsProvider);
    _ref.invalidate(documentByIdProvider(document.id));
    _ref.invalidate(documentSnapshotsProvider(document.id));
  }

  Future<void> setPinned(NxDocument document, bool pinned) async {
    final updated = document.copyWith(
      pinned: pinned,
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _cacheDocument(updated);
    await _ref.read(documentRepositoryProvider).updateDraft(updated);
    _logDbSync('set_pinned', documentId: document.id, detail: 'pinned=$pinned');
    _ref.invalidate(recentDocumentsProvider);
    _ref.invalidate(pinnedDocumentsProvider);
    _ref.invalidate(booksProvider);
  }

  Future<void> attachLinkedModel({
    required int documentId,
    required LinkableModelType modelType,
    required int modelId,
    LinkedModel? model,
  }) async {
    await _ref
        .read(documentRepositoryProvider)
        .attachLinkedModel(
          documentId: documentId,
          modelType: modelType,
          modelId: modelId,
        );
    _logDbSync(
      'attach_link',
      documentId: documentId,
      detail: 'model=${modelType.kgqlName}:$modelId',
    );
    if (model != null) {
      _cacheDocumentWithLink(documentId, model);
    }
  }

  Future<void> attachProject(int documentId, int projectId) async {
    await _ref
        .read(documentRepositoryProvider)
        .attachProject(documentId, projectId);
    _logDbSync(
      'attach_project',
      documentId: documentId,
      detail: 'project=$projectId',
    );
    final projects = _ref
        .read(projectsProvider)
        .maybeWhen(data: (rows) => rows, orElse: () => const <LinkedModel>[]);
    LinkedModel? project;
    for (final item in projects) {
      if (item.id == projectId) {
        project = item;
        break;
      }
    }
    if (project != null) {
      _cacheDocumentWithLink(documentId, project);
    }
  }

  Future<void> detachProject(int documentId, int relationId) async {
    await _ref
        .read(documentRepositoryProvider)
        .detachProject(documentId, relationId);
    _logDbSync(
      'detach_project',
      documentId: documentId,
      detail: 'relation=$relationId',
    );
    final cached = _ref.read(documentLocalCacheProvider)[documentId];
    if (cached == null) return;
    _cacheDocument(
      cached.copyWith(
        links: cached.links
            .where((link) => link.relationId != relationId)
            .toList(),
      ),
    );
  }

  Future<DocumentSnap> createSnapshot(
    int documentId, {
    required String source,
    String changeSummary = '',
  }) async {
    final snap = await _ref
        .read(documentRepositoryProvider)
        .createSnapshot(
          documentId,
          source: source,
          changeSummary: changeSummary,
        );
    _logDbSync(
      'create_snapshot',
      documentId: documentId,
      detail: 'snapshot=${snap.id} source=$source',
    );
    return snap;
  }

  Future<void> restoreSnapshot(NxDocument document, DocumentSnap snap) async {
    await createSnapshot(
      document.id,
      source: 'restore',
      changeSummary: 'Before restore to version ${snap.versionNumber}',
    );
    await saveDraft(
      document.copyWith(
        document: snap.document,
        jsonDocument: snap.jsonDocument,
      ),
      policy: DraftSavePolicy.immediate,
    );
  }

  void _cacheDocument(NxDocument document) {
    _ref.read(documentLocalCacheProvider.notifier).put(document);
  }

  void _cacheDocumentWithLink(int documentId, LinkedModel model) {
    final cached = _ref.read(documentLocalCacheProvider)[documentId];
    if (cached == null ||
        cached.links.any(
          (link) => link.modelType == model.modelType && link.id == model.id,
        )) {
      return;
    }
    _cacheDocument(cached.copyWith(links: [...cached.links, model]));
  }

  void _scheduleDraftWrite() {
    if (_draftWriteInFlight != null) return;
    _draftFlushTimer ??= Timer(_draftWriteDelay, () {
      _draftFlushTimer = null;
      _draftWriteInFlight ??= _flushPendingDraft();
    });
  }

  Future<void> _flushDraftNow() async {
    _draftFlushTimer?.cancel();
    _draftFlushTimer = null;
    if (_draftWriteInFlight != null) {
      await _draftWriteInFlight;
      if (_pendingDraft == null) return;
    }
    _draftWriteInFlight = _flushPendingDraft();
    await _draftWriteInFlight;
  }

  Future<void> _flushPendingDraft() async {
    final draft = _pendingDraft;
    if (draft == null) {
      _draftWriteInFlight = null;
      return;
    }
    _pendingDraft = null;
    try {
      await _ref.read(documentRepositoryProvider).updateDraft(draft);
      _logDbSync(
        'update_draft',
        documentId: draft.id,
        detail: 'words=${draft.wordCount}',
      );
    } finally {
      _draftWriteInFlight = null;
      if (_pendingDraft != null) {
        _scheduleDraftWrite();
      }
    }
  }

  void _logDbSync(String action, {int? documentId, String? detail}) {
    final timestamp = DateTime.now().toIso8601String();
    final documentPart = documentId == null ? '' : ' document=$documentId';
    final detailPart = detail == null ? '' : ' $detail';
    debugPrint(
      '[nx_notes db sync] $timestamp action=$action$documentPart$detailPart',
    );
  }
}

class DocumentResultController {
  DocumentResultController(this._ref);

  final Ref _ref;

  Future<DocumentResultContext> search(String value) async {
    final rows = await _ref.read(documentRepositoryProvider).search(value);
    return DocumentResultContext(
      title: 'Search: $value',
      query: DocumentQuery(searchText: value),
      resultIds: rows.map((document) => document.id).toList(),
      results: rows,
    );
  }

  Future<DocumentResultContext> pinned() async {
    final rows = await _ref
        .read(documentRepositoryProvider)
        .listPinned(limit: 50);
    return DocumentResultContext(
      title: 'Pinned documents',
      query: const DocumentQuery(pinnedOnly: true),
      resultIds: rows.map((document) => document.id).toList(),
      results: rows,
    );
  }

  Future<DocumentResultContext> recent() async {
    final rows = await _ref
        .read(documentRepositoryProvider)
        .listRecent(limit: 50);
    return DocumentResultContext(
      title: 'Recent documents',
      query: const DocumentQuery(),
      resultIds: rows.map((document) => document.id).toList(),
      results: rows,
    );
  }

  Future<DocumentResultContext> tag({
    required String system,
    required String node,
    required bool includeDescendants,
  }) async {
    final filter = DocumentTagFilter(
      system: system,
      node: node,
      includeDescendants: includeDescendants,
    );
    final rows = await _ref.read(documentRepositoryProvider).listByTag(filter);
    return DocumentResultContext(
      title: '$system: $node',
      query: DocumentQuery(tagFilters: <DocumentTagFilter>[filter]),
      resultIds: rows.map((document) => document.id).toList(),
      results: rows,
    );
  }
}
