import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/features/data_browser/images_page.dart';

import '../../_support/fake_image_repository.dart';
import '../../_support/pump_app.dart';

void main() {
  testWidgets('ImagesPage shows necklace title after load', (tester) async {
    final fake = FakeImageRepository(availableDates: const []);
    await pumpMaterialWithProviders(
      tester,
      const ImagesPage(initialSource: 'necklace'),
      overrides: [
        imageRepositoryProvider.overrideWithValue(fake),
        imageBaseUrlProvider.overrideWith((ref) => 'http://img.test'),
        userIdProvider.overrideWith((ref) => 'u1'),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Necklace Images'), findsOneWidget);
  });
}
