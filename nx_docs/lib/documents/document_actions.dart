import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_docs/documents/document_history.dart';
import 'package:nx_docs/documents/document_links.dart';
import 'package:nx_docs/workspace/document_workspace.dart';
import 'package:nx_docs/publishing/document_publish_service.dart';
import 'package:nx_docs/documents/document_providers.dart';
import 'package:nx_docs/publishing/publishing_providers.dart';
import 'package:nx_docs/workspace/workspace_providers.dart';
import 'package:nx_docs/library/models/catalog_query.dart';
import 'package:nx_docs/documents/document_models.dart';

final documentMutationControllerProvider = Provider<DocumentMutationController>(
  DocumentMutationController.new,
);

final documentResultControllerProvider = Provider<DocumentResultController>(
  DocumentResultController.new,
);

enum DraftSavePolicy { deferred, immediate }

class DocumentMutationController {
  DocumentMutationController(this._ref);

  final Ref _ref;

  Future<NxDocument> createDocument({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final document = await _workspace().createDocument(
      title: title,
      kind: kind,
    );
    _logDbSync('create_document', documentId: document.id);
    return document;
  }

  Future<void> saveDraft(
    NxDocument document, {
    DraftSavePolicy policy = DraftSavePolicy.deferred,
  }) async {
    final publish = document.publish.withCurrentContent(
      document.jsonDocument,
      tagsBySystem: document.publishTagsBySystem,
    );
    final draft = document.copyWith(
      publish: publish,
      updatedAt: DateTime.now().toUtc(),
      updatedLabel: 'just now',
    );
    await _workspace().openDocument(document.id).saveDraft(draft);
    if (draft.publish.enabled) {
      unawaited(
        _publishService().notifyEdit(draft).catchError((Object error) {
          debugPrint(
            '[nx_docs mirror publish] edit trigger failed '
            'document=${draft.id} error=$error',
          );
        }),
      );
    }
    if (policy == DraftSavePolicy.immediate) {
      await _workspace().uploadPending();
    }
  }

  Future<void> saveNow(NxDocument fallback) async {
    await saveDraft(fallback, policy: DraftSavePolicy.immediate);
  }

  Future<void> deleteDocument(NxDocument document) async {
    await _workspace().deleteDocument(document.id);
    _logDbSync('delete_document', documentId: document.id);
  }

  Future<void> setPinned(NxDocument document, bool pinned) async {
    await _workspace().openDocument(document.id).setPinned(pinned);
    await _workspace().uploadPending();
    _logDbSync('set_pinned', documentId: document.id, detail: 'pinned=$pinned');
  }

  Future<void> setPublishEnabled(NxDocument document, bool enabled) async {
    await saveNow(document);
    final current = _currentDocument(document.id) ?? document;
    await _publishService().setEnabled(current, enabled);
    _logDbSync(
      'set_publish',
      documentId: document.id,
      detail: 'enabled=$enabled trigger=immediate',
    );
  }

  Future<void> attachLinkedModel({
    required int documentId,
    required LinkableModelType modelType,
    required int modelId,
    LinkedModel? model,
  }) async {
    await _linkService().attach(
      documentId: documentId,
      modelType: modelType,
      modelId: modelId,
    );
    _logDbSync(
      'attach_link',
      documentId: documentId,
      detail: 'model=${modelType.kgqlName}:$modelId',
    );
  }

  Future<void> attachProject(int documentId, int projectId) async {
    await _linkService().attachProject(documentId, projectId);
    _logDbSync(
      'attach_project',
      documentId: documentId,
      detail: 'project=$projectId',
    );
  }

  Future<void> detachProject(int documentId, int relationId) async {
    await _linkService().detachProject(documentId, relationId);
    _logDbSync(
      'detach_project',
      documentId: documentId,
      detail: 'relation=$relationId',
    );
  }

  Future<DocumentSnap> createSnapshot(
    int documentId, {
    required String source,
    String changeSummary = '',
  }) async {
    final snap = await _historyService().create(
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
    await _historyService().restore(document, snap);
  }

  DocumentWorkspace _workspace() {
    final workspace = _ref.read(documentWorkspaceProvider);
    if (workspace == null) throw StateError('Notes are not ready yet.');
    return workspace;
  }

  NxDocument? _currentDocument(int documentId) {
    return _workspace().openDocument(documentId).state.document;
  }

  DocumentHistoryService _historyService() {
    final service = _ref.read(documentHistoryServiceProvider);
    if (service == null) throw StateError('Document history is not ready.');
    return service;
  }

  DocumentLinkService _linkService() {
    final service = _ref.read(documentLinkServiceProvider);
    if (service == null) throw StateError('Document links are not ready.');
    return service;
  }

  DocumentPublishService _publishService() {
    final service = _ref.read(documentPublishServiceProvider);
    if (service == null) throw StateError('Document publishing is not ready.');
    return service;
  }

  void _logDbSync(String action, {int? documentId, String? detail}) {
    final timestamp = DateTime.now().toIso8601String();
    final documentPart = documentId == null ? '' : ' document=$documentId';
    final detailPart = detail == null ? '' : ' $detail';
    debugPrint(
      '[nx_docs db sync] $timestamp action=$action$documentPart$detailPart',
    );
  }
}

class DocumentResultController {
  DocumentResultController(this._ref);

  final Ref _ref;

  Future<DocumentResultContext> search(String value) async {
    final rows = await _readLocalDocuments(DocumentQuery(searchText: value));
    return DocumentResultContext(
      title: 'Search: $value',
      query: DocumentQuery(searchText: value),
      resultIds: rows.map((document) => document.id).toList(),
      results: rows,
    );
  }

  Future<DocumentResultContext> pinned() async {
    final rows = (await _readLocalDocuments(
      const DocumentQuery(pinnedOnly: true),
    )).take(50).toList(growable: false);
    return DocumentResultContext(
      title: 'Pinned documents',
      query: const DocumentQuery(pinnedOnly: true),
      resultIds: rows.map((document) => document.id).toList(),
      results: rows,
    );
  }

  Future<DocumentResultContext> recent() async {
    final rows = (await _readLocalDocuments(
      const DocumentQuery(),
    )).take(50).toList(growable: false);
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
    final rows = await _readLocalDocuments(
      DocumentQuery(tagFilters: <DocumentTagFilter>[filter]),
    );
    return DocumentResultContext(
      title: '$system: $node',
      query: DocumentQuery(tagFilters: <DocumentTagFilter>[filter]),
      resultIds: rows.map((document) => document.id).toList(),
      results: rows,
    );
  }

  Future<List<NxDocument>> _readLocalDocuments(DocumentQuery query) async {
    final workspace = _ref.read(documentWorkspaceProvider);
    if (workspace == null) return const <NxDocument>[];
    final catalogQuery = query.searchText.trim().isNotEmpty
        ? CatalogQuery.search(query.searchText)
        : query.pinnedOnly
        ? const CatalogQuery.pinned(limit: 50)
        : query.tagFilters.isNotEmpty
        ? CatalogQuery.tag(query.tagFilters.first)
        : const CatalogQuery.recent(limit: 50);
    final state = await workspace
        .watchCatalog(catalogQuery)
        .firstWhere((state) => !state.isInitialLoading);
    return state.items
        .map((summary) => summary.toDocument())
        .toList(growable: false);
  }
}
