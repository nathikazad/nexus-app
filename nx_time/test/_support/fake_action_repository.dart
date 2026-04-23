import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/action/action_repository.dart';

class _Edge {
  const _Edge({
    required this.parentId,
    required this.childId,
    required this.relationId,
  });

  final int parentId;
  final int childId;
  final int relationId;
}

/// In-memory [ActionRepository] for widget / view-model tests.
class FakeActionRepository implements ActionRepository {
  FakeActionRepository({
    List<Action>? initial,
    this.delay = Duration.zero,
  }) : _byId = {
          for (final a in initial ?? const <Action>[]) a.id: _stripGraph(a),
        };

  final Map<int, Action> _byId;
  final List<_Edge> _edges = [];
  final Duration delay;
  int _nextId = 100000;
  int _nextRelationId = 500000;

  static Action _stripGraph(Action a) {
    return Action(
      id: a.id,
      name: a.name,
      description: a.description,
      modelTypeId: a.modelTypeId,
      modelTypeName: a.modelTypeName,
      startTime: a.startTime,
      endTime: a.endTime,
    );
  }

  Action _withGraph(Action a) {
    final childIds = <int>[];
    final rel = <int, int>{};
    for (final e in _edges) {
      if (e.parentId == a.id) {
        childIds.add(e.childId);
        rel[e.childId] = e.relationId;
      }
    }
    childIds.sort();
    return Action(
      id: a.id,
      name: a.name,
      description: a.description,
      modelTypeId: a.modelTypeId,
      modelTypeName: a.modelTypeName,
      startTime: a.startTime,
      endTime: a.endTime,
      childActionIds: childIds,
      relationIdByChildId: rel,
    );
  }

  List<Action> get _all => _byId.values.map(_withGraph).toList();

  @override
  Future<List<Action>> listForCalendarDay(DateTime dayLocal) async {
    await Future<void>.delayed(delay);
    final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _all.where((a) {
      final start = a.startTime;
      final end = a.endTime;
      if (start == null && end == null) return false;
      final s = start ?? end!;
      final e = end ?? start!.add(const Duration(hours: 1));
      return s.isBefore(dayEnd) && e.isAfter(dayStart);
    }).toList();
  }

  @override
  Future<List<Action>> listForWeek(DateTime mondayLocal) async {
    await Future<void>.delayed(delay);
    final weekStart = DateTime(mondayLocal.year, mondayLocal.month, mondayLocal.day);
    final fetchStart = weekStart.subtract(const Duration(days: 1));
    final fetchEnd = weekStart.add(const Duration(days: 8));
    return _all.where((a) {
      final s = a.startTime;
      if (s == null) {
        return false;
      }
      return !s.isBefore(fetchStart) && s.isBefore(fetchEnd);
    }).toList();
  }

  @override
  Future<Action?> getById({
    required int id,
    required String modelTypeName,
  }) async {
    await Future<void>.delayed(delay);
    final raw = _byId[id];
    return raw == null ? null : _withGraph(raw);
  }

  @override
  Future<int> create(
    Action action,
    String modelTypeName, {
    int? parentActionId,
  }) async {
    await Future<void>.delayed(delay);
    final id = _nextId++;
    var saved = Action(
      id: id,
      name: action.name,
      description: action.description,
      modelTypeId: action.modelTypeId,
      modelTypeName: modelTypeName,
      startTime: action.startTime,
      endTime: action.endTime,
    );
    _byId[id] = saved;
    if (parentActionId != null) {
      _edges.add(
        _Edge(
          parentId: parentActionId,
          childId: id,
          relationId: _nextRelationId++,
        ),
      );
    }
    return id;
  }

  @override
  Future<int> update(
    Action action, {
    String? modelTypeNameIfChanged,
  }) async {
    await Future<void>.delayed(delay);
    _byId[action.id] = Action(
      id: action.id,
      name: action.name,
      description: action.description,
      modelTypeId: action.modelTypeId,
      modelTypeName: modelTypeNameIfChanged ?? action.modelTypeName,
      startTime: action.startTime,
      endTime: action.endTime,
    );
    return action.id;
  }

  @override
  Future<void> delete(int id) async {
    await Future<void>.delayed(delay);
    _byId.remove(id);
    _edges.removeWhere((e) => e.parentId == id || e.childId == id);
  }

  @override
  Future<int> linkChildAction({
    required int parentId,
    required int childId,
  }) async {
    await Future<void>.delayed(delay);
    if (!_byId.containsKey(parentId) || !_byId.containsKey(childId)) {
      throw StateError('linkChildAction: unknown parent or child');
    }
    _edges.removeWhere((e) => e.parentId == parentId && e.childId == childId);
    final rid = _nextRelationId++;
    _edges.add(_Edge(parentId: parentId, childId: childId, relationId: rid));
    return parentId;
  }

  @override
  Future<void> unlinkChildAction({
    required int parentId,
    required int relationId,
  }) async {
    await Future<void>.delayed(delay);
    _edges.removeWhere((e) => e.parentId == parentId && e.relationId == relationId);
  }
}
