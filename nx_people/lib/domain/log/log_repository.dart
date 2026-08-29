import 'package:nx_people/domain/log/daily_log.dart';

abstract class LogRepository {
  Future<List<DailyLog>> listForCalendarDay(DateTime dayLocal);
  Future<int> create(DailyLogDraft draft);
}
