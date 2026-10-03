import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/account/account_session.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/goals/daily_goal.dart';
import 'package:nx_cards/progress/progress_page.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:nx_offline/nx_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress_analysis_test.dart';

void main() {
  testWidgets(
    'background reload and error retain goal and graph state; new recalls update in place',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final trigger = StateProvider((ref) => 0);
      final initial = [
        progressCard(1, {
          StudyCue.meaningToSound: [review(30, 3)],
        }),
      ];
      Future<List<StudyCard>> response = Future.value(initial);
      final container = ProviderContainer(
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
          sourceProgressCardsProvider.overrideWith((ref, source) {
            ref.watch(trigger);
            return response;
          }),
          reviewProgressionSettingsProvider.overrideWith(
            (ref) async => const ReviewProgressionSettings(
              dailyGoals: {'language:Chinese': 100},
            ),
          ),
          goalNowProvider.overrideWithValue(() => DateTime(2026, 9, 30, 18)),
          goalClockProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 9, 30)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  DailyGoalBar(name: 'Chinese'),
                  Expanded(child: ProgressPage(language: 'Chinese')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 100 recalls'), findsOneWidget);
      final viewState = tester.state(find.byType(ProgressView));
      final pending = Completer<List<StudyCard>>();
      response = pending.future;
      container.read(trigger.notifier).state++;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1 / 100 recalls'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.state(find.byType(ProgressView)), same(viewState));
      pending.complete([
        progressCard(1, {
          StudyCue.meaningToSound: [
            review(30, 3),
            review(30, 3, id: 'new', hour: 13),
          ],
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('2 / 100 recalls'), findsOneWidget);
      expect(tester.state(find.byType(ProgressView)), same(viewState));
      final failed = Completer<List<StudyCard>>();
      response = failed.future;
      container.read(trigger.notifier).state++;
      await tester.pump();
      failed.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 100 recalls'), findsOneWidget);
      expect(tester.state(find.byType(ProgressView)), same(viewState));
      expect(tester.takeException(), isNull);
    },
  );
}
