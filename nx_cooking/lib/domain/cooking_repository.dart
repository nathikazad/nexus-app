import 'package:nx_cooking/domain/stats.dart';

/// In-memory stats tab only. Week / buy use [CookingPlanRepository] + providers.
abstract class CookingRepository {
  CookingStatsSnapshot get stats;
}
