import 'battery_point.dart';

abstract class BatteryRepository {
  Future<List<DateTime>> fetchBatteryDates(
    String baseUrl,
    String userId,
  );

  Future<List<BatteryPoint>> fetchBatteryDay(
    String baseUrl,
    String userId,
    DateTime day,
  );
}
