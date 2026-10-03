import 'package:nx_time/domain/projects/project.dart';
import 'package:nx_time/domain/projects/project_repository.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';

class MultiProjectRepository implements ProjectRepository {
  MultiProjectRepository(this.w);
  final DomainWorkspace w;
  @override
  Future<List<Project>> listAll() async {
    final rows = await Future.wait(
      w.selectedIds.map((id) async {
        final r = await w.projects(id).listAll();
        w.remember(id, r.map((p) => p.id));
        return r;
      }),
    );
    return rows.expand((r) => r).toList();
  }

  @override
  Future<Project?> getById(int id) async =>
      w.projects(await w.owner(id)).getById(id);
  @override
  Future<int> create(Project p, {int? parentProjectId}) async =>
      throw StateError('Choose a destination domain');
  @override
  Future<int> update(Project p) async =>
      w.projects(await w.owner(p.id, write: true)).update(p);
  @override
  Future<void> delete(int id) async =>
      w.projects(await w.owner(id, write: true)).delete(id);
  @override
  Future<int> linkChildProject({
    required int parentId,
    required int childId,
  }) async {
    await w.sameDomain(parentId, childId);
    return w
        .projects(await w.owner(parentId, write: true))
        .linkChildProject(parentId: parentId, childId: childId);
  }

  @override
  Future<void> unlinkChildProject({
    required int parentId,
    required int relationId,
  }) async => w
      .projects(await w.owner(parentId, write: true))
      .unlinkChildProject(parentId: parentId, relationId: relationId);
}
