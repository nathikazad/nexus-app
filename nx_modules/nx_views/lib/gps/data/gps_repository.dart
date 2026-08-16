import 'package:http/http.dart' as http;
import 'package:nx_views/gps/data/gps_chart_service.dart' as svc;
import 'package:nx_views/gps/domain/gps_point.dart';
import 'package:nx_views/gps/domain/gps_repository.dart';

class HttpGpsRepository implements GpsRepository {
  HttpGpsRepository({http.Client? client}) : _client = client;

  final http.Client? _client;

  @override
  Future<List<DateTime>> fetchGpsDates(String baseUrl, String userId) {
    return svc.fetchGpsDates(baseUrl, userId, httpClient: _client);
  }

  @override
  Future<List<GpsPoint>> fetchGpsDay(
    String baseUrl,
    String userId,
    DateTime day,
  ) {
    return svc.fetchGpsDay(baseUrl, userId, day, httpClient: _client);
  }
}
