import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_notes/data/essay/essay_attr_keys.dart';
import 'package:nx_notes/data/essay/essay_mapper.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_repository.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart' as domain_tags;

class KgqlEssayRepository implements EssayRepository {
  KgqlEssayRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadEssaySchema,
    required Future<ModelType> Function() loadEssaySnapSchema,
  }) : _client = client,
       _loadEssaySchema = loadEssaySchema,
       _loadEssaySnapSchema = loadEssaySnapSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadEssaySchema;
  final Future<ModelType> Function() _loadEssaySnapSchema;
  @override
  Future<Essay> create({String? title}) async {
    final id = await setKgqlModel(
      _client,
      setModelRequestForCreateEssay(title: title),
    );
    return essayForCreatedId(id, title: title);
  }

  @override
  Future<EssaySnap> createSnapshot(
    int essayId, {
    required String source,
    String changeSummary = '',
  }) async {
    await _loadEssaySnapSchema();
    final essay = await getById(essayId);
    if (essay == null) {
      throw StateError('Essay $essayId not found');
    }

    final existing = await listSnapshots(essayId);
    final nextVersion = existing.isEmpty
        ? 1
        : existing
                  .map((snap) => snap.versionNumber)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    final snapId = await setKgqlModel(
      _client,
      setModelRequestForCreateSnapshot(
        essay: essay,
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
            ModelRelation(modelType: kEssaySnapModelTypeName, link: [snapId]),
          ],
        ),
      );
    }

    await setKgqlModel(
      _client,
      SetModelRequest(
        id: essayId,
        relations: [
          ModelRelation(modelType: kEssaySnapModelTypeName, link: [snapId]),
        ],
      ),
    );

    return EssaySnap(
      id: snapId,
      essayId: essayId,
      name: changeSummary.trim().isEmpty ? source : changeSummary.trim(),
      versionNumber: nextVersion,
      document: essay.document,
      jsonDocument: essay.jsonDocument,
      source: source,
      changeSummary: changeSummary,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Essay?> getById(int id) async {
    final schema = await _loadEssaySchema();
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kEssayModelTypeName,
      id: id,
      struct: essayFetchStruct(schema),
    );
    if (model == null) return null;
    return essayFromModel(
      model,
      versionNumber: _latestVersionNumberFromEssayModel(model),
    );
  }

  @override
  Future<List<Essay>> listByTag(EssayTagFilter filter) async {
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kEssayModelTypeName,
        'tag_filters': [
          {
            'system': filter.system,
            'node': filter.node,
            'include_descendants': filter.includeDescendants,
          },
        ],
      },
      struct: essaySummaryFetchStruct(),
    );
    return _sortedEssaySummaries(models);
  }

  @override
  Future<List<Essay>> listPinned({int limit = 20}) async {
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kEssayModelTypeName,
        'filters': [
          {'key': kEssayAttrPinned, 'op': '=', 'value': true},
        ],
      },
      struct: essaySummaryFetchStruct(),
    );
    return _sortedEssaySummaries(models).take(limit).toList();
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
    required int essayId,
    required LinkableModelType modelType,
    required int modelId,
  }) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: essayId,
        relations: [
          ModelRelation(modelType: modelType.kgqlName, link: [modelId]),
        ],
      ),
    );
  }

  @override
  Future<void> attachProject(int essayId, int projectId) async {
    await attachLinkedModel(
      essayId: essayId,
      modelType: LinkableModelType.project,
      modelId: projectId,
    );
  }

  @override
  Future<void> detachProject(int essayId, int relationId) async {
    await setKgqlModel(
      _client,
      SetModelRequest(
        id: essayId,
        relations: [ModelRelation(id: relationId, delete: true)],
      ),
    );
  }

  @override
  Future<List<Essay>> listRecent({int limit = 20}) async {
    final rows = await _listAll();
    return rows.take(limit).toList();
  }

  @override
  Future<List<EssaySnap>> listSnapshots(int essayId) async {
    final schema = await _loadEssaySchema();
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kEssayModelTypeName,
      id: essayId,
      struct: essayFetchStruct(schema),
    );
    if (model == null) return const <EssaySnap>[];
    return essaySnapsFromEssayModel(model);
  }

  @override
  Future<List<domain_tags.TagSystem>> listTagSystems() async {
    final schema = await _loadEssaySchema();
    final essays = await _listAllSummaries();
    return [
      for (final system in schema.tagSystems ?? const <TagSystem>[])
        domain_tags.TagSystem(
          name: system.name,
          hierarchical: system.isHierarchical,
          exclusive: system.selectionMode == 'exclusive',
          nodes: [
            for (final node in system.nodes)
              _mapTagNode(node, system.name, essays),
          ],
        ),
    ];
  }

  @override
  Future<List<Essay>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <Essay>[];
    final rows = await _listAllSummaries();
    return rows.where((essay) {
      return [
        essay.title,
        essay.document,
        essay.excerpt,
        essay.status,
        ...essay.tagsBySystem.values.expand((tags) => tags),
      ].join(' ').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Future<Essay> updateDraft(Essay essay) async {
    await setKgqlModel(_client, setModelRequestForUpdateEssay(essay));
    return essay.copyWith(updatedAt: DateTime.now(), updatedLabel: 'just now');
  }

  @override
  Future<void> delete(int id) async {
    await setKgqlModel(_client, SetModelRequest(id: id, delete: true));
  }

  Future<List<Essay>> _listAll() async {
    final models = await fetchKgqlModels(
      _client,
      filter: {'model_type': kEssayModelTypeName},
      struct: essaySummaryFetchStruct(),
    );
    return _sortedEssaySummaries(models);
  }

  Future<List<Essay>> _listAllSummaries() => _listAll();

  List<Essay> _sortedEssaySummaries(List<Model> models) {
    final rows = [for (final model in models) essaySummaryFromModel(model)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  int _latestVersionNumberFromEssayModel(Model model) {
    final snaps = essaySnapsFromEssayModel(model);
    if (snaps.isEmpty) return 0;
    return snaps.first.versionNumber;
  }

  domain_tags.TagNode _mapTagNode(
    TagNode node,
    String system,
    List<Essay> essays,
  ) {
    final children = [
      for (final child in node.children ?? const <TagNode>[])
        _mapTagNode(child, system, essays),
    ];
    final count = essays
        .where((essay) => _essayHasTag(essay, system, node.name))
        .length;
    return domain_tags.TagNode(
      name: node.name,
      count: count,
      children: children,
    );
  }

  bool _essayHasTag(Essay essay, String system, String node) {
    return switch (system) {
      kEssayStatusTagSystem => essay.status == node,
      _ => essay.tagsBySystem[system]?.contains(node) ?? false,
    };
  }
}
