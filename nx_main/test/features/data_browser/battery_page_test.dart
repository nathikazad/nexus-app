import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/features/data_browser/battery_page.dart';

import '../../_support/fake_battery_repository.dart';
import '../../_support/pump_app.dart';

void main() {
  testWidgets('BatteryPage shows app bar title', (tester) async {
    final fake = FakeBatteryRepository(dates: const []);
    await pumpMaterialWithProviders(
      tester,
      const BatteryPage(),
      overrides: [
        batteryRepositoryProvider.overrideWithValue(fake),
        imageBaseUrlProvider.overrideWith((ref) => 'http://img.test'),
        userIdProvider.overrideWith((ref) => 'u1'),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Necklace battery'), findsOneWidget);
  });
}
