import 'package:nx_notes/domain/essay/essay.dart';
import 'package:nx_notes/domain/essay/essay_query.dart';
import 'package:nx_notes/domain/essay/essay_snap.dart';
import 'package:nx_notes/domain/links/linked_model.dart';
import 'package:nx_notes/domain/tags/tag_system.dart';

abstract class EssayRepository {
  Future<List<Essay>> listRecent({int limit = 20});
  Future<List<Essay>> listPinned({int limit = 20});
  Future<List<Essay>> search(String query);
  Future<List<Essay>> listByTag(EssayTagFilter filter);
  Future<Essay?> getById(int id);
  Future<Essay> create();
  Future<Essay> updateDraft(Essay essay);
  Future<EssaySnap> createSnapshot(
    int essayId, {
    required String source,
    String changeSummary = '',
  });
  Future<List<EssaySnap>> listSnapshots(int essayId);
  Future<List<TagSystem>> listTagSystems();
  Future<List<LinkedModel>> listProjects();
  Future<List<LinkedModel>> searchLinkableModels({
    required LinkableModelType modelType,
    required String query,
  });
  Future<void> attachLinkedModel({
    required int essayId,
    required LinkableModelType modelType,
    required int modelId,
  });
  Future<void> attachProject(int essayId, int projectId);
  Future<void> detachProject(int essayId, int relationId);
}
