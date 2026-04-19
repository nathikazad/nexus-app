import 'package:nexus_voice_assistant/data/images/image_service.dart' as svc;
import 'package:nexus_voice_assistant/domain/images/image_entry.dart';
import 'package:nexus_voice_assistant/domain/images/image_repository.dart';

/// HTTP implementation of [ImageRepository] (delegates to [svc]).
class HttpImageRepository implements ImageRepository {
  @override
  Future<List<DateTime>> fetchAvailableDates(
    String baseUrl,
    String userId,
    String source,
  ) {
    return svc.fetchAvailableDates(baseUrl, userId, source);
  }

  @override
  Future<List<ImageEntry>> fetchImagesForDay(
    String baseUrl,
    String userId,
    String source,
    DateTime day,
  ) {
    return svc.fetchImagesForDay(baseUrl, userId, source, day);
  }
}
