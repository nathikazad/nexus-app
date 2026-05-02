import 'package:nx_time/domain/log/daily_log.dart';

/// Loads and mutates Daily Log rows via the data layer (KGQL by default).
abstract class LogRepository {
  /// Logs whose `logged_at` falls in [dayLocal]'s calendar day (local midnight to next).
  Future<List<DailyLog>> listForCalendarDay(DateTime dayLocal);

  Future<DailyLog?> getById(int id);

  /// Returns the new model id.
  Future<int> create({
    required DateTime loggedAt,
    String? entry,
    Map<String, List<String>> tags = const {},
  });

  Future<int> update({
    required int id,
    required DateTime loggedAt,
    String? entry,
    Map<String, List<String>> tags = const {},
  });

  Future<void> delete(int id);
}
