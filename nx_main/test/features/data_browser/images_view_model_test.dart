import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/images/image_entry.dart';
import 'package:nexus_voice_assistant/features/data_browser/images_view_model.dart';

import '../../_support/fake_image_repository.dart';

void main() {
  group('ImagesViewNotifier', () {
    test('loadDates sets error when not logged in', () async {
      final fake = FakeImageRepository();
      final container = ProviderContainer(
        overrides: [
          imageRepositoryProvider.overrideWithValue(fake),
          imageBaseUrlProvider.overrideWith((ref) => null),
          userIdProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(imagesViewModelProvider('necklace').notifier).loadDates();
      final s = container.read(imagesViewModelProvider('necklace'));
      expect(s.loading, isFalse);
      expect(s.error, isNotNull);
      expect(s.error, contains('Not logged in'));
    });

    test('loadDates loads availability and day images', () async {
      final day1 = DateTime(2020, 6, 1);
      final day2 = DateTime(2020, 6, 2);
      final entries = [
        const ImageEntry(
          url: 'http://x/a.jpg',
          filename: 'a.jpg',
          minutesSinceMidnight: 60,
        ),
        const ImageEntry(
          url: 'http://x/b.jpg',
          filename: 'b.jpg',
          minutesSinceMidnight: 120,
        ),
      ];
      final fake = FakeImageRepository(
        availableDates: [day1, day2],
        imagesForDay: entries,
      );
      final container = ProviderContainer(
        overrides: [
          imageRepositoryProvider.overrideWithValue(fake),
          imageBaseUrlProvider.overrideWith((ref) => 'http://img'),
          userIdProvider.overrideWith((ref) => 'u1'),
        ],
      );
      addTearDown(container.dispose);

      final prov = imagesViewModelProvider('desktop');
      await container.read(prov.notifier).loadDates();
      final s = container.read(prov);
      expect(s.loading, isFalse);
      expect(s.error, isNull);
      expect(s.available, {day1, day2});
      expect(s.dayEntries, entries);
      expect(s.sliderValue, 60);
      expect(s.minTime, 60);
      expect(s.maxTime, 120);
    });

    test('stepPrev and stepNext move slider between marks', () async {
      final day1 = DateTime(2019, 1, 1);
      final entries = [
        const ImageEntry(
          url: 'http://x/a.jpg',
          filename: 'a.jpg',
          minutesSinceMidnight: 10,
        ),
        const ImageEntry(
          url: 'http://x/b.jpg',
          filename: 'b.jpg',
          minutesSinceMidnight: 90,
        ),
      ];
      final fake = FakeImageRepository(
        availableDates: [day1],
        imagesForDay: entries,
      );
      final container = ProviderContainer(
        overrides: [
          imageRepositoryProvider.overrideWithValue(fake),
          imageBaseUrlProvider.overrideWith((ref) => 'http://img'),
          userIdProvider.overrideWith((ref) => 'u1'),
        ],
      );
      addTearDown(container.dispose);

      final prov = imagesViewModelProvider('necklace');
      await container.read(prov.notifier).loadDates();
      final n = container.read(prov.notifier);
      expect(container.read(prov).sliderValue, 10);

      n.stepNext();
      expect(container.read(prov).sliderValue, 90);

      n.stepPrev();
      expect(container.read(prov).sliderValue, 10);
    });
  });
}
