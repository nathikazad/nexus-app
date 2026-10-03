import 'package:nx_cards/goals/streak_badge.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/goals/daily_goal.dart';
import 'package:nx_cards/progress/progress_page.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:nx_cards/browser/browser.dart';
import '../progress/progress_analysis_test.dart' show progressCard;

void main() {
  test(
    'streak survives unfinished today, extends at target, and stops at a gap',
    () {
      final now = DateTime(2026, 10, 2, 12);
      final counts = {
        DateTime(2026, 9, 28): 100,
        DateTime(2026, 9, 30): 100,
        DateTime(2026, 10, 1): 110,
        DateTime(2026, 10, 2): 99,
      };
      expect(dailyGoalStreak(counts, 100, now), 2);
      counts[DateTime(2026, 10, 2)] = 100;
      expect(dailyGoalStreak(counts, 100, now), 3);
      expect(dailyGoalStreak(counts, 0, now), 0);
      counts.remove(DateTime(2026, 10, 1));
      expect(dailyGoalStreak(counts, 100, now), 0);
      expect(dailyGoalStreak({}, 100, now), 0);
    },
  );
  testWidgets(
    'flame appears only for active streak and fits narrow enlarged text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final yesterday in [false, true]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProgressCardsProvider.overrideWith(
                (ref, source) async => [
                  progressCard(1, {
                    StudyCue.meaningToScript: [
                      if (yesterday)
                        CardReview(
                          id: 'yesterday',
                          reviewedAt: DateTime(2026, 10, 1, 10),
                          rating: 1,
                          elapsedSeconds: 0,
                          scheduledSeconds: 0,
                        ),
                    ],
                  }),
                ],
              ),
              reviewProgressionSettingsProvider.overrideWith(
                (ref) async => const ReviewProgressionSettings(
                  dailyGoals: {'language:Chinese': 1},
                ),
              ),
              goalNowProvider.overrideWithValue(
                () => DateTime(2026, 10, 2, 12),
              ),
              goalClockProvider.overrideWith(
                (ref) => Stream.value(DateTime(2026, 10, 2, 12)),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(1.7)),
                  child: DailyGoalBar(name: 'Chinese'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(StreakBadge),
          yesterday ? findsOneWidget : findsNothing,
        );
        if (yesterday) {
          expect(
            find.bySemanticsLabel(RegExp('1-day daily goal streak')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'book goal opens scoped progress without language recall controls',
    (tester) async {
      final requested = <ProgressSource>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCardsSessionProvider.overrideWith(
              (ref) async => const CachedSession(
                serverId: 'test',
                userId: 'user',
                domainId: 1,
                application: 'nx_cards',
                route: 'test',
              ),
            ),
            sourceProgressCardsProvider.overrideWith((ref, source) async {
              requested.add(source);
              return [];
            }),
            reviewProgressionSettingsProvider.overrideWith(
              (ref) async => const ReviewProgressionSettings(),
            ),
            goalNowProvider.overrideWithValue(() => DateTime(2026, 10, 2)),
            goalClockProvider.overrideWith(
              (ref) => Stream.value(DateTime(2026, 10, 2)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DailyGoalBar(name: 'Example book', bookId: 42),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daily-goal-bar')));
      await tester.pumpAndSettle();
      expect(find.text('Example book · Progress'), findsOneWidget);
      expect(
        requested.every(
          (source) => source.bookId == 42 && source.language == null,
        ),
        true,
      );
      expect(find.byKey(const ValueKey('progress-direction')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('preferences default to zero and preserve independent source goals', () {
    final settings = ReviewProgressionSettings.fromJson({
      'daily_goals': {
        'language:Chinese': 100,
        'language:Malayalam': 30,
        'book:42': 20,
        'bad': -1,
      },
    });
    expect(settings.dailyGoals['language:Chinese'], 100);
    expect(settings.dailyGoals['language:Malayalam'], 30);
    expect(settings.dailyGoals['book:42'], 20);
    expect(settings.dailyGoals.containsKey('bad'), false);
    expect(ReviewProgressionSettings.fromJson({}).dailyGoals, isEmpty);
    expect(
      ReviewProgressionSettings.fromJson(settings.toJson()).dailyGoals,
      settings.dailyGoals,
    );
  });
  test(
    'daily attempts deduplicate sync repeats, count failures, and respect midnight',
    () {
      final now = DateTime(2026, 10, 2, 12);
      CardReview r(String id, DateTime time) => CardReview(
        id: id,
        reviewedAt: time.toUtc(),
        rating: 1,
        elapsedSeconds: 0,
        scheduledSeconds: 0,
      );
      final a = r('a', DateTime(2026, 10, 2, 0));
      final cards = [
        progressCard(1, {
          StudyCue.meaningToScript: [
            a,
            a,
            r('old', DateTime(2026, 10, 1, 23, 59)),
            r('future', DateTime(2026, 10, 3)),
          ],
          StudyCue.soundToMeaning: [r('b', now)],
        }),
      ];
      expect(recallsToday(cards, now), 2);
      expect(recallsToday(cards, DateTime(2026, 10, 3)), 1);
      expect(goalKey(language: 'Chinese'), 'language:Chinese');
      expect(goalKey(bookId: 42), 'book:42');
    },
  );
  testWidgets('goal bar handles unset and exceeded goals without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final goal in [0, 1]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sourceProgressCardsProvider.overrideWith(
              (ref, source) async => [
                progressCard(1, {
                  StudyCue.meaningToScript: [
                    for (var i = 0; i < 2; i++)
                      CardReview(
                        id: '$i',
                        reviewedAt: DateTime(2026, 10, 2, 10),
                        rating: 3,
                        elapsedSeconds: 0,
                        scheduledSeconds: 0,
                      ),
                  ],
                }),
              ],
            ),
            reviewProgressionSettingsProvider.overrideWith(
              (ref) async => ReviewProgressionSettings(
                dailyGoals: {'language:Chinese': goal},
              ),
            ),
            goalNowProvider.overrideWithValue(() => DateTime(2026, 10, 2, 12)),
            goalClockProvider.overrideWith(
              (ref) => Stream.value(DateTime(2026, 10, 2, 12)),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
                child: DailyGoalBar(name: 'Chinese'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('daily-goal-bar')), findsOneWidget);
      expect(
        find.text(goal == 0 ? 'No goal set' : '2 / 1 recalls'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
