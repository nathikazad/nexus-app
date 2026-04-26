import 'package:nx_projects/domain/project/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> listRootProjects();
  Future<Project?> getProject(int id);
  Future<List<Project>> getSubProjects(int parentId);
  Future<Project> addProject(Project project);
  Future<Project> addSubProject(int parentId, Project sub);
}
