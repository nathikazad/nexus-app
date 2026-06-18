import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_notes/data/document/document_attr_keys.dart';
import 'package:nx_notes/data/document/document_mapper.dart';
import 'package:nx_notes/domain/document/document.dart';
import 'package:nx_notes/domain/document/document_query.dart';
import 'package:nx_notes/domain/document/document_repository.dart';
import 'package:nx_notes/domain/document/document_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart' as domain_tags;

class KgqlDocumentRepository implements DocumentRepository {
  KgqlDocumentRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadDocumentSchema,
    required Future<ModelType> Function() loadDocumentSnapSchema,
  }) : _client = client,
       _loadDocumentSchema = loadDocumentSchema,
       _loadDocumentSnapSchema = loadDocumentSnapSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadDocumentSchema;
  final Future<ModelType> Function() _loadDocumentSnapSchema;
  @override
  Future<NxDocument> create({
    String? title,
    DocumentKind kind = DocumentKind.document,
  }) async {
    final id = await setKgqlModel(
      _client,
      setModelRequestForCreateDocument(title: title, kind: kind),
    );
    return documentForCreatedId(id, title: title, kind: kind);
  }

  @override
  Future<DocumentSnap> createSnapshot(
    int documentId, {
    required String source,
    String changeSummary = '',
  }) async {
    await _loadDocumentSnapSchema();
    final document = await getById(documentId);
    if (document == null) {
      throw StateError('Document $documentId not found');
    }

    final existing = await listSnapshots(documentId);
    final nextVersion = existing.isEmpty
        ? 1
        : existing
                  .map((snap) => snap.versionNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final snapId = await setKgqlModel(
      _client,
      setModelRequestForCreateSnapshot(
        document: document,
        versionNumber: nextVersion,
        source: source,
        name: changeSummary.trim().isEmpty ? source : changeSummary.trim(),
        changeSummary: changeSummary.trim().isEmpty
            ? null
            : <String, dynamic>{'message': changeSummary},
      ),
    );

    if (existing.isNotEmpty) {
      await setKgqlModel(
        _client,
        SetModelRequest(
          id: existing.first.id,
          relations: [
            ModelRelation(
              modelType: kDocumentSnapModelTypeName,
              link: [snapId],
            ),
          ],
        ),
      );
    }

    await setKgqlModel(
      _client,
      SetModelRequest(
        id: documentId,
        relations: [
          ModelRelation(modelType: kDocumentSnapModelTypeName, link: [snapId]),
        ],
      ),
    );

    return DocumentSnap(
      id: snapId,
      documentId: documentId,
      name: changeSummary.trim().isEmpty ? source : changeSummary.trim(),
      versionNumber: nextVersion,
      document: document.document,
      jsonDocument: document.jsonDocument,
      source: source,
      changeSummary: changeSummary,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<NxDocument?> getById(int id) async {
    final schema = await _loadDocumentSchema();
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kDocumentModelTypeName,
      id: id,
      struct: documentFetchStruct(schema),
    );
    if (model == null) return null;
    return documentFromModel(
      model,
      versionNumber: _latestVersionNumberFromDocumentModel(model),
    );
  }

  @override
  Future<List<NxDocument>> listByTag(DocumentTagFilter filter) async {
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kDocumentModelTypeName,
        'tag_filters': [
          {
            'system': filter.system,
            'node': filter.node,
            'include_descendants': filter.includeDescendants,
          },
        ],
      },
      struct: documentSummaryFetchStruct(),
    );
    return _sortedDocumentSummaries(models);
  }

  @override
  Future<List<NxDocument>> listPinned({int limit = 20}) async {
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kDocumentModelTypeName,
        'filters': [
          {'key': kDocumentAttrPinned, 'op': '=', 'value': true},
        ],
      },
      struct: documentSummaryFetchStruct(),
    );
    return _sortedDocumentSummaries(models).take(limit).toList();
  }

  @override
  Future<List<NxDocument>> listBooks({int limit = 50}) async {
    final models = await fetchKgqlModels(
      _client,
      filter: {'model_type': kBookModelTypeName},
      struct: documentSummaryFetchStruct(),
    );
    return _sortedDocumentSummaries(models).take(limit).toList();
  }

  @override
  Future<List<LinkedModel>> listProjects() async {
    return searchLinkableModels(
      modelType: LinkableModelType.project,
      query: '',
    );
  }

  @override
  Future<List<LinkedModel>> searchLinkableModels({
    required LinkableModelType modelType,
    required String query,
  }) async {
    final models = await fetchKgqlModelsForRelationPicker(
      _client,
      modelType.kgqlName,
    );
    final normalized = query.trim().toLowerCase();
    return [
      for (final model in models)
        if (normalized.isEmpty ||
            model.name.toLowerCase().contains(normalized) ||
            (model.description ?? '').toLowerCase().contains(normalized))
          LinkedModel(
            id: model.id,
            name: model.name,
            modelType: modelType.kgqlName,
          ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> attachLinkedModel({
    required int documentId,
    required LinkableModelType modelType,
    required int modelId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: documentId,
        relations: [
          ModelRelation(modelType: modelType.kgqlName, link: [modelId]),
        ],
      ),
    );
  }

  @override
  Future<void> attachProject(int documentId, int projectId) async {
    await attachLinkedModel(
      documentId: documentId,
      modelType: LinkableModelType.project,
      modelId: projectId,
    );
  }

  @override
  Future<void> detachProject(int documentId, int relationId) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: documentId,
        relations: [ModelRelation(id: relationId, delete: true)],
      ),
    );
  }

  @override
  Future<List<NxDocument>> listRecent({int limit = 20}) async {
    final rows = await _listAll();
    return rows.take(limit).toList();
  }

  @override
  Future<List<DocumentSnap>> listSnapshots(int documentId) async {
    final schema = await _loadDocumentSchema();
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kDocumentModelTypeName,
      id: documentId,
      struct: documentFetchStruct(schema),
    );
    if (model == null) return const <DocumentSnap>[];
    return documentSnapsFromDocumentModel(model);
  }

  @override
  Future<List<domain_tags.TagSystem>> listTagSystems() async {
    final schema = await _loadDocumentSchema();
    final documents = await _listAllSummaries();
    return [
      for (final system in schema.tagSystems ?? const <TagSystem>[])
        domain_tags.TagSystem(
          name: system.name,
          hierarchical: system.isHierarchical,
          exclusive: system.selectionMode == 'exclusive',
          nodes: [
            for (final node in system.nodes)
              _mapTagNode(node, system.name, documents),
          ],
        ),
    ];
  }

  @override
  Future<List<NxDocument>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <NxDocument>[];
    final rows = await _listAllSummaries();
    return rows.where((document) {
      return [
        document.title,
        document.document,
        document.excerpt,
        document.status,
        ...document.tagsBySystem.values.expand((tags) => tags),
      ].join(' ').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<NxDocument> updateDraft(NxDocument document) async {
    await setKgqlModel(_client, setModelRequestForUpdateDocument(document));
    return document.copyWith(
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, SetModelRequest(id: id, delete: true));
  }

  Future<List<NxDocument>> _listAll() async {
    final models = await fetchKgqlModels(
      _client,
      filter: {'model_type': kDocumentModelTypeName},
      struct: documentSummaryFetchStruct(),
    );
    return _sortedDocumentSummaries(models);
  }

  Future<List<NxDocument>> _listAllSummaries() => _listAll();

  List<NxDocument> _sortedDocumentSummaries(List<Model> models) {
    final rows = [for (final model in models) documentSummaryFromModel(model)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  int _latestVersionNumberFromDocumentModel(Model model) {
    final snaps = documentSnapsFromDocumentModel(model);
    if (snaps.isEmpty) return 0;
    return snaps.first.versionNumber;
  }

  domain_tags.TagNode _mapTagNode(
    TagNode node,
    String system,
    List<NxDocument> documents,
  ) {
    final children = [
      for (final child in node.children ?? const <TagNode>[])
        _mapTagNode(child, system, documents),
    ];
    final count = documents
        .where((document) => _documentHasTag(document, system, node.name))
        .length;
    return domain_tags.TagNode(
      name: node.name,
      count: count,
      children: children,
    );
  }

  bool _documentHasTag(NxDocument document, String system, String node) {
    return switch (system) {
      kDocumentStatusTagSystem => document.status == node,
      _ => document.tagsBySystem[system]?.contains(node) ?? false,
    };
  }
}
