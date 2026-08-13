import 'package:nx_views/gps/data/gps_chart_service.dart' as svc;
import 'package:nx_views/gps/domain/gps_point.dart';
import 'package:nx_views/gps/domain/gps_repository.dart';

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
