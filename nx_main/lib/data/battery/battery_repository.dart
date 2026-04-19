import 'package:nexus_voice_assistant/data/battery/battery_chart_service.dart' as svc;
import 'package:nexus_voice_assistant/domain/battery/battery_point.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_repository.dart';

/// HTTP implementation of [BatteryRepository] (delegates to [svc]).
class HttpBatteryRepository implements BatteryRepository {
  @override
  Future<List<DateTime>> fetchBatteryDates(
    String baseUrl,
    String userId,
  ) {
    return svc.fetchBatteryDates(baseUrl, userId);
  }

  @override
  Future<List<BatteryPoint>> fetchBatteryDay(
    String baseUrl,
    String userId,
    DateTime day,
  ) {
    return svc.fetchBatteryDay(baseUrl, userId, day);
  }
}
