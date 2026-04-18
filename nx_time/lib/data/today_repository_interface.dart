import 'models/today_snapshot.dart';

/// Loads [TodaySnapshot] for the Today tab (fake data or KGQL-backed).
abstract class TodayRepository {
  Future<TodaySnapshot> loadToday([DateTime? forDay]);
}
