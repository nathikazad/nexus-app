import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_db/auth.dart';
import 'package:nx_db/nx_db.dart' show ImageEntry;
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/features/data_browser/images_page.dart';

import '../../_support/fake_image_repository.dart';
import '../../_support/pump_app.dart';

void main() {
  testWidgets('image waits for authentication headers before loading',
      (tester) async {
    final headers = Completer<Map<String, String>>();
    final fake = FakeImageRepository(
      availableDates: [DateTime(2026, 9, 26)],
      imagesForDay: const [
        ImageEntry(
          url: 'https://img.test/photo.jpg',
          filename: 'photo.jpg',
          minutesSinceMidnight: 60,
        ),
      ],
    );
    await pumpMaterialWithProviders(
      tester,
      const ImagesPage(),
      overrides: [
        imageRepositoryProvider.overrideWithValue(fake),
        imageBaseUrlProvider.overrideWith((ref) => 'https://img.test'),
        userIdProvider.overrideWith((ref) => 'u1'),
        nexusRequestHeadersProvider.overrideWith((ref) => headers.future),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);

    headers.complete({'authorization': 'Bearer test', 'x-domain-id': '7'});
    await tester.pump();
    await tester.pump();
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.httpHeaders, {
      'authorization': 'Bearer test',
      'x-domain-id': '7',
    });
  });

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
