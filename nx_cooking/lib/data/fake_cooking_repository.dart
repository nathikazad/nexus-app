import 'package:nx_cooking/domain/cooking_repository.dart';
import 'package:nx_cooking/domain/stats.dart';

/// In-memory stats only (week / buy are DB-backed).
final class FakeCookingRepository implements CookingRepository {
  FakeCookingRepository();

  @override
  CookingStatsSnapshot get stats => const CookingStatsSnapshot(
    mealsCooked: '2',
    totalTimeLabel: '3h 10m',
    cookedThisWeek: [
      StatMealRow(
        title: 'Classic Beef Stew',
        whenLabel: 'Sunday',
        durationLabel: '2h 15m',
      ),
      StatMealRow(
        title: 'Omelette',
        whenLabel: 'Monday morning',
        durationLabel: '15m',
      ),
    ],
  );
}
