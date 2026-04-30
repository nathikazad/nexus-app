import 'image_entry.dart';

abstract class ImageRepository {
  Future<List<DateTime>> fetchAvailableDates(
    String baseUrl,
    String userId,
    String source,
  );

  Future<List<ImageEntry>> fetchImagesForDay(
    String baseUrl,
    String userId,
    String source,
    DateTime day,
  );
}
