import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_notes/data/providers.dart';
import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_result_context.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';

final essayMutationControllerProvider = Provider<EssayMutationController>(
  EssayMutationController.new,
);

final essayResultControllerProvider = Provider<EssayResultController>(
  EssayResultController.new,
);

class EssayMutationController {
  EssayMutationController(this._ref);

  final Ref _ref;

  Future<Essay> createEssay() async {
    final essay = await _ref.read(essayRepositoryProvider).create();
    _invalidateLists();
    _ref.invalidate(tagSystemsProvider);
    return essay;
  }

  Future<void> saveDraft(Essay essay) async {
    await _ref.read(essayRepositoryProvider).updateDraft(essay);
    _invalidateEssay(essay.id);
    _invalidateLists();
    _ref.invalidate(tagSystemsProvider);
  }

  Future<void> attachLinkedModel({
    required int essayId,
    required LinkableModelType modelType,
    required int modelId,
  }) async {
    await _ref
        .read(essayRepositoryProvider)
        .attachLinkedModel(
          essayId: essayId,
          modelType: modelType,
          modelId: modelId,
        );
    _invalidateEssay(essayId);
    _ref.invalidate(recentEssaysProvider);
  }

  Future<void> attachProject(int essayId, int projectId) async {
    await _ref.read(essayRepositoryProvider).attachProject(essayId, projectId);
    _invalidateEssay(essayId);
    _ref.invalidate(recentEssaysProvider);
  }

  Future<void> detachProject(int essayId, int relationId) async {
    await _ref.read(essayRepositoryProvider).detachProject(essayId, relationId);
    _invalidateEssay(essayId);
    _ref.invalidate(recentEssaysProvider);
  }

  Future<EssaySnap> createSnapshot(
    int essayId, {
    required String source,
    String changeSummary = '',
  }) async {
    final snap = await _ref
        .read(essayRepositoryProvider)
        .createSnapshot(essayId, source: source, changeSummary: changeSummary);
    _invalidateEssay(essayId);
    _ref.invalidate(essaySnapshotsProvider(essayId));
    return snap;
  }

  Future<void> restoreSnapshot(Essay essay, EssaySnap snap) async {
    await createSnapshot(
      essay.id,
      source: 'restore',
      changeSummary: 'Before restore to version ${snap.versionNumber}',
    );
    await saveDraft(
      essay.copyWith(document: snap.document, jsonDocument: snap.jsonDocument),
    );
    _ref.invalidate(essaySnapshotsProvider(essay.id));
  }

  void _invalidateEssay(int essayId) {
    _ref.invalidate(essayByIdProvider(essayId));
  }

  void _invalidateLists() {
    _ref.invalidate(recentEssaysProvider);
    _ref.invalidate(pinnedEssaysProvider);
  }
}

class EssayResultController {
  EssayResultController(this._ref);

  final Ref _ref;

  Future<EssayResultContext> search(String value) async {
    final rows = await _ref.read(essayRepositoryProvider).search(value);
    return EssayResultContext(
      title: 'Search: $value',
      query: EssayQuery(searchText: value),
      resultIds: rows.map((essay) => essay.id).toList(),
    );
  }

  Future<EssayResultContext> pinned() async {
    final rows = await _ref.read(essayRepositoryProvider).listPinned(limit: 50);
    return EssayResultContext(
      title: 'Pinned essays',
      query: const EssayQuery(pinnedOnly: true),
      resultIds: rows.map((essay) => essay.id).toList(),
    );
  }

  Future<EssayResultContext> recent() async {
    final rows = await _ref.read(essayRepositoryProvider).listRecent(limit: 50);
    return EssayResultContext(
      title: 'Recent essays',
      query: const EssayQuery(),
      resultIds: rows.map((essay) => essay.id).toList(),
    );
  }

  Future<EssayResultContext> tag({
    required String system,
    required String node,
    required bool includeDescendants,
  }) async {
    final filter = EssayTagFilter(
      system: system,
      node: node,
      includeDescendants: includeDescendants,
    );
    final rows = await _ref.read(essayRepositoryProvider).listByTag(filter);
    return EssayResultContext(
      title: '$system: $node',
      query: EssayQuery(tagFilters: <EssayTagFilter>[filter]),
      resultIds: rows.map((essay) => essay.id).toList(),
    );
  }
}
