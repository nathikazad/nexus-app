import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_notes/data/essay/essay_attr_keys.dart';
import 'package:nx_notes/data/essay/essay_mapper.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_repository.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/tags/tag_system.dart' as domain_tags;

class KgqlEssayRepository implements EssayRepository {
  KgqlEssayRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadEssaySchema,
    required Future<ModelType> Function() loadEssaySnapSchema,
    required int domainId,
  }) : _client = client,
       _loadEssaySchema = loadEssaySchema,
       _loadEssaySnapSchema = loadEssaySnapSchema,
       _domainId = domainId;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadEssaySchema;
  final Future<ModelType> Function() _loadEssaySnapSchema;
  final int _domainId;

  @override
  Future<Essay> create() async {
    final id = await setKgqlModel(
      _client,
      setModelRequestForCreateEssay(),
      domainId: _domainId,
    );
    final essay = await getById(id);
    if (essay == null) {
      throw StateError('Created essay $id could not be loaded');
    }
    return essay;
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
        changeSummary: changeSummary.trim().isEmpty
            ? null
            : <String, dynamic>{'message': changeSummary},
      ),
      domainId: _domainId,
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
        domainId: _domainId,
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
      domainId: _domainId,
    );

    final snaps = await listSnapshots(essayId);
    return snaps.firstWhere((snap) => snap.id == snapId);
  }

  @override
  Future<Essay?> getById(int id) async {
    final schema = await _loadEssaySchema();
    final model = await fetchKgqlModelById(
      _client,
      modelTypeName: kEssayModelTypeName,
      id: id,
      struct: essayFetchStruct(schema),
      domainId: _domainId,
    );
    if (model == null) return null;
    return essayFromModel(
      model,
      versionNumber: _latestVersionNumberFromEssayModel(model),
    );
  }

  @override
  Future<List<Essay>> listByTag(EssayTagFilter filter) async {
    final schema = await _loadEssaySchema();
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
      struct: essayFetchStruct(schema),
      domainId: _domainId,
    );
    return _sortedEssays(models);
  }

  @override
  Future<List<Essay>> listPinned({int limit = 20}) async {
    final schema = await _loadEssaySchema();
    final models = await fetchKgqlModels(
      _client,
      filter: {
        'model_type': kEssayModelTypeName,
        'filters': [
          {'key': kEssayAttrPinned, 'op': '=', 'value': true},
        ],
      },
      struct: essayFetchStruct(schema),
      domainId: _domainId,
    );
    return _sortedEssays(models).take(limit).toList();
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
      domainId: _domainId,
    );
    if (model == null) return const <EssaySnap>[];
    return essaySnapsFromEssayModel(model);
  }

  @override
  Future<List<domain_tags.TagSystem>> listTagSystems() async {
    final schema = await _loadEssaySchema();
    final essays = await _listAll();
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
    final rows = await _listAll();
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
    final schema = await _loadEssaySchema();
    await setKgqlModel(
      _client,
      setModelRequestForUpdateEssay(
        essay,
        availableTagSystems: _availableTagSystems(schema),
      ),
      domainId: _domainId,
    );
    final updated = await getById(essay.id);
    if (updated == null) {
      throw StateError('Updated essay ${essay.id} could not be loaded');
    }
    return updated;
  }

  Set<String> _availableTagSystems(ModelType schema) {
    return {
      for (final system in schema.tagSystems ?? const <TagSystem>[])
        system.name,
    };
  }

  Future<List<Essay>> _listAll() async {
    final schema = await _loadEssaySchema();
    final models = await fetchKgqlModels(
      _client,
      filter: {'model_type': kEssayModelTypeName},
      struct: essayFetchStruct(schema),
      domainId: _domainId,
    );
    return _sortedEssays(models);
  }

  List<Essay> _sortedEssays(List<Model> models) {
    final rows = [
      for (final model in models)
        essayFromModel(
          model,
          versionNumber: _latestVersionNumberFromEssayModel(model),
        ),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
