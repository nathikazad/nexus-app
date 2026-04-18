import 'package:nx_time/domain/action/action.dart';
import 'package:nx_time/domain/action/action_repository.dart';

/// In-memory [ActionRepository] for widget / view-model tests.
class FakeActionRepository implements ActionRepository {
  FakeActionRepository({
    List<Action>? initial,
    this.delay = Duration.zero,
  }) : _byId = {
          for (final a in initial ?? const <Action>[]) a.id: a,
        };

  final Map<int, Action> _byId;
  final Duration delay;
  int _nextId = 100000;

  List<Action> get _all => _byId.values.toList();

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
  Future<Action?> getById({
    required int id,
    required String modelTypeName,
  }) async {
    await Future<void>.delayed(delay);
    return _byId[id];
  }

  @override
  Future<int> create(Action action, String modelTypeName) async {
    await Future<void>.delayed(delay);
    final id = _nextId++;
    final saved = Action(
      id: id,
      name: action.name,
      description: action.description,
      modelTypeId: action.modelTypeId,
      modelTypeName: modelTypeName,
      startTime: action.startTime,
      endTime: action.endTime,
    );
    _byId[id] = saved;
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
  }
}
