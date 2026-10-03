import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('always uses five regardless of legacy settings', () async {
    final store = ReviewProgressionSettingsStore();
    expect((await store.load()).historyWindow, 5);
    await expectLater(
      store.save(const ReviewProgressionSettings()),
      throwsStateError,
    );
  });
  test('offline cache is account scoped', () async {
    SharedPreferences.setMockInitialValues({
      'nx_cards.account_preferences.v2.one':
          '{"history_window":10,"daily_goals":{"language:Chinese":100}}',
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
      5,
    );
  });
  test(
    'saving sends the fixed five and preserves returned daily goals',
    () async {
      var calls = 0;
      final store = ReviewProgressionSettingsStore(
        accountKey: 'one',
        userId: 1,
        client: GraphQLClient(
          cache: GraphQLCache(),
          link: Link.function((request, [forward]) async* {
            calls++;
            expect(request.variables, {'window': 5});
            yield Response(
              response: const {},
              data: {
                '__typename': 'Mutation',
                'setCardsRecallWindow': {
                  'history_window': 5,
                  'daily_goals': {'language:Chinese': 100},
                },
              },
            );
          }),
        ),
      );
      await store.save(const ReviewProgressionSettings());
      expect(calls, 1);
      final saved = await ReviewProgressionSettingsStore(
        accountKey: 'one',
      ).load();
      expect(saved.historyWindow, 5);
      expect(saved.dailyGoals, {'language:Chinese': 100});
      expect(
        (await ReviewProgressionSettingsStore(
          accountKey: 'two',
        ).load()).dailyGoals,
        isEmpty,
      );
    },
  );
  test('cannot claim account save while signed out', () async {
    await expectLater(
      ReviewProgressionSettingsStore().save(const ReviewProgressionSettings()),
      throwsStateError,
    );
  });
}
