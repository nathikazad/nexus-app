import 'gps_point.dart';

abstract class GpsRepository {
  Future<List<DateTime>> fetchGpsDates(
    String baseUrl,
    String userId,
  );

  Future<List<GpsPoint>> fetchGpsDay(
    String baseUrl,
    String userId,
    DateTime day,
  );
}
