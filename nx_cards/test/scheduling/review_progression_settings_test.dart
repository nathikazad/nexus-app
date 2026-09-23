import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('defaults to ten; rejects invalid windows', () async {
    final store = ReviewProgressionSettingsStore();
    expect((await store.load()).historyWindow, 10);
    await expectLater(
      store.save(const ReviewProgressionSettings(historyWindow: 0)),
      throwsArgumentError,
    );
  });
  test('offline cache is account scoped', () async {
    SharedPreferences.setMockInitialValues({
      'nx_cards.account_preferences.v2.one': '{"history_window":5}',
    });
    expect(
      (await ReviewProgressionSettingsStore(
        accountKey: 'one',
      ).load()).historyWindow,
      5,
    );
    expect(
      (await ReviewProgressionSettingsStore(
        accountKey: 'two',
      ).load()).historyWindow,
      10,
    );
  });
  test('cannot claim account save while signed out', () async {
    await expectLater(
      ReviewProgressionSettingsStore().save(const ReviewProgressionSettings()),
      throwsStateError,
    );
  });
}
