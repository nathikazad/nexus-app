import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/action/action_repository.dart';
import 'package:nx_time/data/domains/domain_workspace.dart';

class PersonalActionRepository implements ActionRepository {
  PersonalActionRepository(this.w);
  final DomainWorkspace w;
  @override
  Future<List<Action>> listForCalendarDay(DateTime dayLocal) async {
    final rows = await w.actions(w.personalId).listForCalendarDay(dayLocal);
    w.remember(w.personalId, rows.map((r) => r.id));
    return rows;
  }

  @override
  Future<List<Action>> listForWeek(DateTime mondayLocal) async {
    final rows = await w.actions(w.personalId).listForWeek(mondayLocal);
    w.remember(w.personalId, rows.map((r) => r.id));
    return rows;
  }

  @override
  Future<Action?> getById({
    required int id,
    required String modelTypeName,
  }) async => w
      .actions(await w.owner(id))
      .getById(id: id, modelTypeName: modelTypeName);
  @override
  Future<int> create(
    Action action,
    String modelTypeName, {
    int? parentActionId,
  }) async => throw StateError('Choose a destination domain');
  @override
  Future<int> update(Action action, {String? modelTypeNameIfChanged}) async => w
      .actions(await w.owner(action.id, write: true))
      .update(action, modelTypeNameIfChanged: modelTypeNameIfChanged);
  @override
  Future<void> delete(int id) async =>
      w.actions(await w.owner(id, write: true)).delete(id);
  @override
  Future<int> linkChildAction({
    required int parentId,
    required int childId,
  }) async {
    await w.sameDomain(parentId, childId);
    return w
        .actions(await w.owner(parentId, write: true))
        .linkChildAction(parentId: parentId, childId: childId);
  }

  @override
  Future<void> unlinkChildAction({
    required int parentId,
    required int relationId,
  }) async => w
      .actions(await w.owner(parentId, write: true))
      .unlinkChildAction(parentId: parentId, relationId: relationId);
}
