import 'package:nx_time/domain/log/daily_log.dart';
import 'package:nx_time/domain/log/log_repository.dart';

class FakeLogRepository implements LogRepository {
  FakeLogRepository({List<DailyLog>? initial, this.delay = Duration.zero})
    : _logs = [...?initial];

  final List<DailyLog> _logs;
  final Duration delay;
  int _nextId = 100000;

  @override
  Future<List<DailyLog>> listForCalendarDay(DateTime dayLocal) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final start = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final end = start.add(const Duration(days: 1));
    return _logs.where((log) {
      final loggedAt = log.loggedAt;
      return loggedAt != null &&
          !loggedAt.isBefore(start) &&
          loggedAt.isBefore(end);
    }).toList();
  }

  @override
  Future<DailyLog?> getById(int id) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    for (final log in _logs) {
      if (log.id == id) {
        return log;
      }
    }
    return null;
  }

  @override
  Future<int> create({
    required DateTime loggedAt,
    String? entry,
    Map<String, List<String>> tags = const {},
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final id = _nextId++;
    _logs.add(
      DailyLog(
        id: id,
        modelTypeId: 1,
        loggedAt: loggedAt,
        entry: entry,
        tags: tags,
      ),
    );
    return id;
  }

  @override
  Future<void> delete(int id) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    _logs.removeWhere((log) => log.id == id);
  }

  @override
  Future<int> update({
    required int id,
    required DateTime loggedAt,
    String? entry,
    Map<String, List<String>> tags = const {},
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final i = _logs.indexWhere((log) => log.id == id);
    if (i >= 0) {
      _logs[i] = DailyLog(
        id: id,
        modelTypeId: _logs[i].modelTypeId,
        loggedAt: loggedAt,
        entry: entry,
        tags: tags,
      );
    }
    return id;
  }
}
