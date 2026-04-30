import 'package:nx_db/nx_db.dart';

class FakeImageRepository implements ImageRepository {
  FakeImageRepository({
    this.availableDates = const [],
    this.imagesForDay = const [],
    this.onFetchDates,
    this.onFetchDay,
  });

  List<DateTime> availableDates;
  List<ImageEntry> imagesForDay;
  final Future<List<DateTime>> Function(
    String baseUrl,
    String userId,
    String source,
  )? onFetchDates;
  final Future<List<ImageEntry>> Function(
    String baseUrl,
    String userId,
    String source,
    DateTime day,
  )? onFetchDay;

  @override
  Future<List<DateTime>> fetchAvailableDates(
    String baseUrl,
    String userId,
    String source,
  ) {
    if (onFetchDates != null) {
      return onFetchDates!(baseUrl, userId, source);
    }
    return Future.value(List<DateTime>.from(availableDates));
  }

  @override
  Future<List<ImageEntry>> fetchImagesForDay(
    String baseUrl,
    String userId,
    String source,
    DateTime day,
  ) {
    if (onFetchDay != null) {
      return onFetchDay!(baseUrl, userId, source, day);
    }
    return Future.value(List<ImageEntry>.from(imagesForDay));
  }
}
