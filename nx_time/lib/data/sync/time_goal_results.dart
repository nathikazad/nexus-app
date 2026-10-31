import 'dart:async';
import 'dart:convert';
import 'package:nx_time/data/sync/time_store.dart';

/// Reads server-computed results from the same scoped durable sync snapshot.
class TimeGoalResults {
  TimeGoalResults(
    this.store, {
    required this.requestMonths,
    required this.pull,
  });
  final TimeStore store;
  final Future<void> Function(List<String>, DateTime) requestMonths;
  final Future<void> Function() pull;
  final List<String> _months = [];
  Future<void>? _refresh;
  String? _requested;
  DateTime? _anchored;
  bool closed = false;

  String day(DateTime d) => d.toIso8601String().substring(0, 10);
  String month(DateTime d) => day(DateTime(d.year, d.month));

  Future<Map<String, dynamic>> _records() async {
    final raw = await store.library.read('time_goal_results', 'snapshot');
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, dynamic>?> cached(
    String view,
    DateTime start,
    int? goalId,
  ) async {
    final records = await _records();
    final date = day(start);
    if (view == 'month_score') {
      final row = records['goal-result:month_score:$date'];
      return row == null
          ? null
          : Map<String, dynamic>.from(row['payload']['result'] as Map);
    }
    // Month-score is emitted even when there are zero goals: it proves coverage.
    final covered = records.values.any((row) {
      final p = row['payload'];
      if (p['view'] != 'month_score') return false;
      final m = DateTime.parse(p['period_start'] as String);
      if (view == 'month') return day(m) == date;
      return start.isBefore(DateTime(m.year, m.month + 1)) &&
          start.add(const Duration(days: 7)).isAfter(m);
    });
    if (!covered) return null;
    final items = [
      for (final row in records.values)
        if (row['payload']['view'] == view &&
            row['payload']['period_start'] == date &&
            (goalId == null || row['payload']['goal_id'] == goalId))
          row['payload']['result'],
    ];
    return {
      view == 'week' ? 'week_start' : 'month_start': date,
      'items': items,
    };
  }

  Future<Map<String, dynamic>> read(
    String view,
    DateTime start,
    int? goalId,
  ) async {
    final needed = month(
      view == 'week' ? start.add(const Duration(days: 3)) : start,
    );
    _months.remove(needed);
    _months.add(needed);
    while (_months.length > 3) {
      _months.removeAt(0);
    }
    await store.library.saveRemote(
      'time_goal_results',
      'months',
      jsonEncode(_months),
    );
    final previous = await cached(view, start, goalId);
    if (previous != null) {
      // Publication notifies the UI only if content changed; avoid refresh loops.
      if (_requested != jsonEncode(_months) ||
          _anchored == null ||
          DateTime.now().difference(_anchored!) > const Duration(minutes: 1)) {
        unawaited(refresh().catchError((Object _) {}));
      }
      return previous;
    }
    await refresh();
    final result = await cached(view, start, goalId);
    if (result == null)
      throw StateError('Goal results have not synced for this period');
    return result;
  }

  Future<void> refresh() =>
      _refresh ??= _run().whenComplete(() => _refresh = null);
  Future<void> _run() async {
    if (_months.isEmpty) {
      final saved = await store.library.read('time_goal_results', 'months');
      if (saved != null)
        _months.addAll((jsonDecode(saved) as List).cast<String>());
    }
    if (_months.isEmpty || closed) return;
    while (!closed) {
      final months = List<String>.of(_months);
      final key = jsonEncode(months);
      final now = DateTime.now();
      await requestMonths(months, now);
      if (closed) return;
      // The endpoint queues publication; a ready manifest may take a few seconds.
      for (var attempt = 0; ; attempt++) {
        try {
          await pull();
          break;
        } catch (_) {
          if (closed || attempt >= 9) rethrow;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      _requested = key;
      _anchored = now;
      if (key == jsonEncode(_months)) return;
    }
  }

  Future<void> close() async {
    closed = true;
    try {
      await _refresh;
    } catch (_) {}
  }
}
