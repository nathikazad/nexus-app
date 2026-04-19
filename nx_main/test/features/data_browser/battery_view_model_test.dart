import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/domain/battery/battery_point.dart';
import 'package:nexus_voice_assistant/features/data_browser/battery_view_model.dart';

import '../../_support/fake_battery_repository.dart';

void main() {
  group('BatteryViewNotifier', () {
    test('loadDates sets error when not logged in', () async {
      final fake = FakeBatteryRepository();
      final container = ProviderContainer(
        overrides: [
          batteryRepositoryProvider.overrideWithValue(fake),
          imageBaseUrlProvider.overrideWith((ref) => null),
          userIdProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(batteryViewModelProvider.notifier).loadDates();
      final s = container.read(batteryViewModelProvider);
      expect(s.loading, isFalse);
      expect(s.error, isNotNull);
      expect(s.error, contains('Not logged in'));
    });

    test('loadDates loads availability and day points', () async {
      final day1 = DateTime(2020, 3, 1);
      final day2 = DateTime(2020, 3, 2);
      final pts = [
        const BatteryPoint(
          timeHms: '10:00:00',
          percent: 80,
          voltageMv: 4100,
          charging: false,
        ),
        const BatteryPoint(
          timeHms: '11:30:00',
          percent: 70,
          voltageMv: 4000,
          charging: true,
        ),
      ];
      final fake = FakeBatteryRepository(
        dates: [day1, day2],
        dayPoints: pts,
      );
      final container = ProviderContainer(
        overrides: [
          batteryRepositoryProvider.overrideWithValue(fake),
          imageBaseUrlProvider.overrideWith((ref) => 'http://img'),
          userIdProvider.overrideWith((ref) => 'u1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(batteryViewModelProvider.notifier).loadDates();
      final s = container.read(batteryViewModelProvider);
      expect(s.loading, isFalse);
      expect(s.error, isNull);
      expect(s.available, {day1, day2});
      expect(s.points, pts);
    });
  });
}
