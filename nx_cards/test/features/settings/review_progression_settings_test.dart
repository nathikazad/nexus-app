import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/features/settings/review_progression_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('uses safe defaults and persists user settings', () async {
    final store = ReviewProgressionSettingsStore();
    final defaults = await store.load();
    expect(defaults.automaticProgressionEnabled, isTrue);
    expect(defaults.historyWindow, 5);
    expect(defaults.moveToPastPercentage, 100);
    expect(defaults.moveToCurrentPercentage, 60);
    expect(defaults.autoReplacePromotedCards, isTrue);

    const changed = ReviewProgressionSettings(
      automaticProgressionEnabled: false,
      historyWindow: 7,
      moveToPastPercentage: 90,
      moveToCurrentPercentage: 50,
      autoReplacePromotedCards: false,
    );
    await store.save(changed);

    final restored = await ReviewProgressionSettingsStore().load();
    expect(restored.automaticProgressionEnabled, isFalse);
    expect(restored.historyWindow, 7);
    expect(restored.moveToPastPercentage, 90);
    expect(restored.moveToCurrentPercentage, 50);
    expect(restored.autoReplacePromotedCards, isFalse);
  });

  test('rejects overlapping thresholds', () async {
    await expectLater(
      ReviewProgressionSettingsStore().save(
        const ReviewProgressionSettings(
          moveToPastPercentage: 60,
          moveToCurrentPercentage: 60,
        ),
      ),
      throwsArgumentError,
    );
  });
}
