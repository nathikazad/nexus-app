import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nx_views/gps/data/gps_repository.dart' as data_gps;
import 'package:nx_views/gps/domain/gps_repository.dart';

final gpsRepositoryProvider = Provider<GpsRepository>((ref) {
  return data_gps.HttpGpsRepository();
});
