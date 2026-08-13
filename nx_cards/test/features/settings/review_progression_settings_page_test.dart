import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/composition/cards_composition.dart';
import 'package:nx_cards/features/settings/review_progression_settings.dart';
import 'package:nx_cards/features/settings/review_progression_settings_page.dart';

void main() {
  testWidgets('full sync reports downloaded card count', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewProgressionSettingsProvider.overrideWith(
            (ref) async => const ReviewProgressionSettings(),
          ),
          cardsFullSyncProvider.overrideWithValue(() async => 420),
        ],
        child: const MaterialApp(home: ReviewProgressionSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('full-sync-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('full-sync-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Full sync complete. 420 cards downloaded.'),
      findsOneWidget,
    );
  });

  testWidgets('full sync disables the button and displays errors', (
    tester,
  ) async {
    final completion = Completer<int>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewProgressionSettingsProvider.overrideWith(
            (ref) async => const ReviewProgressionSettings(),
          ),
          cardsFullSyncProvider.overrideWithValue(() => completion.future),
        ],
        child: const MaterialApp(home: ReviewProgressionSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('full-sync-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('full-sync-button')));
    await tester.pump();
    expect(find.text('Synchronizing…'), findsOneWidget);

    completion.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Full sync failed:'), findsOneWidget);
  });
}
