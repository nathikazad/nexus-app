import 'package:nx_projects/domain/sprint/sprint.dart';

abstract class SprintRepository {
  Future<List<Sprint>> listSprints();
  Future<Sprint?> getById(int id);
  Future<void> update(Sprint sprint);
}
