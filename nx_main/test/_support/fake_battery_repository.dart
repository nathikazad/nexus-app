import 'package:nexus_voice_assistant/domain/battery/battery_point.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_repository.dart';

class FakeBatteryRepository implements BatteryRepository {
  FakeBatteryRepository({
    this.dates = const [],
    this.dayPoints = const [],
    this.onFetchDates,
    this.onFetchDay,
  });

  List<DateTime> dates;
  List<BatteryPoint> dayPoints;
  final Future<List<DateTime>> Function(
    String baseUrl,
    String userId,
  )? onFetchDates;
  final Future<List<BatteryPoint>> Function(
    String baseUrl,
    String userId,
    DateTime day,
  )? onFetchDay;

  @override
  Future<List<DateTime>> fetchBatteryDates(
    String baseUrl,
    String userId,
  ) {
    if (onFetchDates != null) {
      return onFetchDates!(baseUrl, userId);
    }
    return Future.value(List<DateTime>.from(dates));
  }

  @override
  Future<List<BatteryPoint>> fetchBatteryDay(
    String baseUrl,
    String userId,
    DateTime day,
  ) {
    if (onFetchDay != null) {
      return onFetchDay!(baseUrl, userId, day);
    }
    return Future.value(List<BatteryPoint>.from(dayPoints));
  }
}
