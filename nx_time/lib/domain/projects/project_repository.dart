import 'package:nx_time/domain/projects/project.dart';

/// Loads and mutates [Project] rows via the data layer (KGQL by default).
abstract class ProjectRepository {
  Future<List<Project>> listAll();

  Future<Project?> getById(int id);

  /// Creates a project; [parentProjectId] links via `has_subproject`.
  Future<int> create(Project project, {int? parentProjectId});

  Future<int> update(Project project);

  Future<void> delete(int id);

  Future<int> linkChildProject({required int parentId, required int childId});

  Future<void> unlinkChildProject({
    required int parentId,
    required int relationId,
  });
}
