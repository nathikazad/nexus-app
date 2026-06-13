import 'dart:async';

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
  EssayMutationController(this._ref) {
    _ref.onDispose(() {
      _draftFlushTimer?.cancel();
    });
  }

  final Ref _ref;
  static const Duration _draftWriteInterval = Duration(seconds: 90);
  Timer? _draftFlushTimer;
  DateTime? _lastDraftWriteAt;
  Essay? _pendingDraft;
  Future<void>? _draftWriteInFlight;

  Future<Essay> createEssay({String? title}) async {
    final essay = await _ref.read(essayRepositoryProvider).create(title: title);
    _cacheEssay(essay);
    return essay;
  }

  Future<void> saveDraft(Essay essay) async {
    _pendingDraft = essay.copyWith(
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _cacheEssay(_pendingDraft!);
    _scheduleDraftWrite();
  }

  Future<void> saveNow(Essay fallback) async {
    _draftFlushTimer?.cancel();
    _draftFlushTimer = null;
    _pendingDraft ??= fallback.copyWith(
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _cacheEssay(_pendingDraft!);
    if (_draftWriteInFlight != null) {
      await _draftWriteInFlight;
      if (_pendingDraft == null) return;
    }
    _draftWriteInFlight = _flushPendingDraft();
    await _draftWriteInFlight;
  }

  Future<void> deleteEssay(Essay essay) async {
    _draftFlushTimer?.cancel();
    _draftFlushTimer = null;
    if (_draftWriteInFlight != null) {
      await _draftWriteInFlight;
    }
    _pendingDraft = null;
    await _ref.read(essayRepositoryProvider).delete(essay.id);
    _ref.read(essayLocalCacheProvider.notifier).remove(essay.id);
    _ref.invalidate(recentEssaysProvider);
    _ref.invalidate(pinnedEssaysProvider);
    _ref.invalidate(tagSystemsProvider);
    _ref.invalidate(essayByIdProvider(essay.id));
    _ref.invalidate(essaySnapshotsProvider(essay.id));
  }

  Future<void> setPinned(Essay essay, bool pinned) async {
    final updated = essay.copyWith(
      pinned: pinned,
      updatedAt: DateTime.now(),
      updatedLabel: 'just now',
    );
    _cacheEssay(updated);
    await _ref.read(essayRepositoryProvider).updateDraft(updated);
    _lastDraftWriteAt = DateTime.now();
    _ref.invalidate(recentEssaysProvider);
    _ref.invalidate(pinnedEssaysProvider);
  }

  Future<void> attachLinkedModel({
    required int essayId,
    required LinkableModelType modelType,
    required int modelId,
    LinkedModel? model,
  }) async {
    await _ref
        .read(essayRepositoryProvider)
        .attachLinkedModel(
          essayId: essayId,
          modelType: modelType,
          modelId: modelId,
        );
    if (model != null) {
      _cacheEssayWithLink(essayId, model);
    }
  }

  Future<void> attachProject(int essayId, int projectId) async {
    await _ref.read(essayRepositoryProvider).attachProject(essayId, projectId);
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
      _cacheEssayWithLink(essayId, project);
    }
  }

  Future<void> detachProject(int essayId, int relationId) async {
    await _ref.read(essayRepositoryProvider).detachProject(essayId, relationId);
    final cached = _ref.read(essayLocalCacheProvider)[essayId];
    if (cached == null) return;
    _cacheEssay(
      cached.copyWith(
        links: cached.links
            .where((link) => link.relationId != relationId)
            .toList(),
      ),
    );
  }

  Future<EssaySnap> createSnapshot(
    int essayId, {
    required String source,
    String changeSummary = '',
  }) async {
    final snap = await _ref
        .read(essayRepositoryProvider)
        .createSnapshot(essayId, source: source, changeSummary: changeSummary);
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
  }

  void _cacheEssay(Essay essay) {
    _ref.read(essayLocalCacheProvider.notifier).put(essay);
  }

  void _cacheEssayWithLink(int essayId, LinkedModel model) {
    final cached = _ref.read(essayLocalCacheProvider)[essayId];
    if (cached == null ||
        cached.links.any(
          (link) => link.modelType == model.modelType && link.id == model.id,
        )) {
      return;
    }
    _cacheEssay(cached.copyWith(links: [...cached.links, model]));
  }

  void _scheduleDraftWrite() {
    if (_draftWriteInFlight != null) return;

    final now = DateTime.now();
    final lastWriteAt = _lastDraftWriteAt;
    if (lastWriteAt == null ||
        now.difference(lastWriteAt) >= _draftWriteInterval) {
      _draftFlushTimer?.cancel();
      _draftFlushTimer = null;
      _draftWriteInFlight = _flushPendingDraft();
      return;
    }

    _draftFlushTimer ??= Timer(
      _draftWriteInterval - now.difference(lastWriteAt),
      () {
        _draftFlushTimer = null;
        _draftWriteInFlight ??= _flushPendingDraft();
      },
    );
  }

  Future<void> _flushPendingDraft() async {
    final draft = _pendingDraft;
    if (draft == null) {
      _draftWriteInFlight = null;
      return;
    }
    _pendingDraft = null;
    try {
      await _ref.read(essayRepositoryProvider).updateDraft(draft);
      _lastDraftWriteAt = DateTime.now();
    } finally {
      _draftWriteInFlight = null;
      if (_pendingDraft != null) {
        _scheduleDraftWrite();
      }
    }
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
      results: rows,
    );
  }

  Future<EssayResultContext> pinned() async {
    final rows = await _ref.read(essayRepositoryProvider).listPinned(limit: 50);
    return EssayResultContext(
      title: 'Pinned essays',
      query: const EssayQuery(pinnedOnly: true),
      resultIds: rows.map((essay) => essay.id).toList(),
      results: rows,
    );
  }

  Future<EssayResultContext> recent() async {
    final rows = await _ref.read(essayRepositoryProvider).listRecent(limit: 50);
    return EssayResultContext(
      title: 'Recent essays',
      query: const EssayQuery(),
      resultIds: rows.map((essay) => essay.id).toList(),
      results: rows,
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
      results: rows,
    );
  }
}
