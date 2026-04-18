import 'models/today_snapshot.dart';

/// Loads [TodaySnapshot] for the Today tab (KGQL-backed by default; tests may override).
abstract class TodayRepository {
  Future<TodaySnapshot> loadToday([DateTime? forDay]);
}
