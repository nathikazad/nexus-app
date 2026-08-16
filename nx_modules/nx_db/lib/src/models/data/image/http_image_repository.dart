import 'package:http/http.dart' as http;
import 'package:nx_db/src/models/data/image/image_service.dart' as svc;
import 'package:nx_db/src/models/domain/image/image_entry.dart';
import 'package:nx_db/src/models/domain/image/image_repository.dart';

/// HTTP implementation of [ImageRepository] (delegates to [svc]).
class HttpImageRepository implements ImageRepository {
  HttpImageRepository({http.Client? client}) : _client = client;

  final http.Client? _client;

  @override
  Future<List<DateTime>> fetchAvailableDates(
    String baseUrl,
    String userId,
    String source,
  ) {
    return svc.fetchAvailableDates(
      baseUrl,
      userId,
      source,
      httpClient: _client,
    );
  }

  @override
  Future<List<ImageEntry>> fetchImagesForDay(
    String baseUrl,
    String userId,
    String source,
    DateTime day,
  ) {
    return svc.fetchImagesForDay(
      baseUrl,
      userId,
      source,
      day,
      httpClient: _client,
    );
  }
}
