import 'package:nx_projects/domain/project/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> listRootProjects();
  Future<Project?> getProject(String id);
  Future<List<Project>> getSubProjects(String parentId);
  Future<Project> addProject(Project project);
  Future<Project> addSubProject(String parentId, Project sub);
}
