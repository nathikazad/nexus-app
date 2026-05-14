import 'package:nexus_voice_assistant/data/gps/gps_chart_service.dart' as svc;
import 'package:nexus_voice_assistant/domain/gps/gps_point.dart';
import 'package:nexus_voice_assistant/domain/gps/gps_repository.dart';

class HttpGpsRepository implements GpsRepository {
  @override
  Future<List<DateTime>> fetchGpsDates(String baseUrl, String userId) {
    return svc.fetchGpsDates(baseUrl, userId);
  }

  @override
  Future<List<GpsPoint>> fetchGpsDay(
    String baseUrl,
    String userId,
    DateTime day,
  ) {
    return svc.fetchGpsDay(baseUrl, userId, day);
  }
}
