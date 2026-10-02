import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/progress/progress_analysis.dart';
import 'package:nx_cards/scheduling/retention.dart';

CardReview review(int day, int rating, {String? id, int hour = 12}) =>
    CardReview(
      id: id ?? '$day-$hour',
      reviewedAt: DateTime(2026, 9, day, hour),
      rating: rating,
      elapsedSeconds: 0,
      scheduledSeconds: 0,
    );

StudyCard progressCard(
  int id,
  Map<StudyCue, List<CardReview>> history, {
  List<String> path = const ['Script'],
}) => StudyCard(
  id: id,
  content: LanguageCardContent(
    english: 'word $id',
    originalScript: '字$id',
    transliteration: 'zi',
  ),
  schedules: const {},
  reviewHistory: history,
  suspended: false,
  learningStatus: LearningStatus.recall,
  modelTypeName: 'LanguageFlashcard',
  tags: const {
    'Language': ['Chinese'],
  },
  categoryPaths: [path],
);

void main() {
  test('weekly and monthly buckets sum recalls but retain ending balances', () {
    final report = ProgressAnalysis(
      days: [
        for (var d = 1; d <= 30; d++)
          ProgressDay(DateTime(2026, 9, d), d + 10, d + 10, 2),
        ProgressDay(DateTime(2026, 10, 1), 38, 40, 5),
        ProgressDay(DateTime(2026, 10, 2), 41, 41, 7),
      ],
      milestones: [],
      cardCount: 100,
      reviewedCount: 50,
      firstReview: null,
      firstAudioReview: null,
      openingCount: 10,
    );
    final weeks = groupProgress(
      report,
      ProgressInterval.week,
      DateTime(2026, 10, 2, 12),
    );
    expect(weeks.first.date, DateTime(2026, 9, 6));
    expect(weeks.first.recalls, 12);
    expect(weeks.first.atTarget, 16);
    expect(weeks.first.change, 6);
    expect(weeks.first.partial, isTrue); // selection starts Tuesday
    expect(weeks[1].start, DateTime(2026, 9, 7));
    expect(weeks[1].partial, isFalse);
    expect(weeks.last.partial, isTrue);
    expect(weeks.fold<int>(0, (n, b) => n + b.recalls), 72);
    expect(weeks.fold<int>(0, (n, b) => n + b.change), 31);
    final months = groupProgress(
      report,
      ProgressInterval.month,
      DateTime(2026, 10, 2, 12),
    );
    expect(months.length, 2);
    expect(months.first.atTarget, 40);
    expect(months.first.recalls, 60);
    expect(months.first.partial, isFalse);
    expect(months.last.change, 1);
    expect(months.last.recalls, 12);
    final days = groupProgress(
      report,
      ProgressInterval.day,
      DateTime(2026, 10, 2, 12),
    );
    expect(days[30].change, -2);
  });

  test(
    'range opening balance prevents pre-range learning being counted as new',
    () {
      final report = analyzeProgress(
        cards: [
          progressCard(1, {
            StudyCue.fromLanguage: [review(1, 3), review(2, 3), review(3, 3)],
          }),
        ],
        directions: {StudyCue.fromLanguage},
        targetPercent: 50,
        now: DateTime(2026, 9, 30, 12),
        start: DateTime(2026, 9, 7),
      );
      expect(report.openingCount, 1);
      final weeks = groupProgress(
        report,
        ProgressInterval.week,
        DateTime(2026, 9, 30, 12),
      );
      expect(
        weeks.every((b) => b.atTarget == 1 && b.change == 0 && b.recalls == 0),
        isTrue,
      );
    },
  );

  final english = {StudyCue.fromLanguage};
  ProgressAnalysis run(
    List<StudyCard> cards, {
    int target = 50,
    DateTime? start,
    DateTime? end,
    Set<StudyCue>? directions,
  }) => analyzeProgress(
    cards: cards,
    directions: directions ?? english,
    targetPercent: target,
    now: DateTime(2026, 9, 30, 18),
    start: start,
    end: end,
  );

  test(
    'replays earlier reviews before clipping and preserves zero-activity days',
    () {
      final card = progressCard(1, {
        StudyCue.fromLanguage: [for (var d = 1; d <= 3; d++) review(d, 3)],
      });
      final result = run([card], start: DateTime(2026, 9, 10));
      expect(result.days.length, 21);
      expect(
        result.days.every(
          (d) => d.atTarget == 1 && d.everReached == 1 && d.recalls == 0,
        ),
        isTrue,
      );
      expect(result.milestones, isEmpty);
      expect(result.reviewedCount, 1);
    },
  );

  test(
    'deduplicates per direction, orders reviews, excludes future events',
    () {
      final r = review(1, 3);
      final result = run([
        progressCard(1, {
          StudyCue.fromLanguage: [
            review(3, 3),
            r,
            r,
            review(2, 3),
            review(31, 3),
          ],
        }),
      ]);
      expect(result.recalls, 3);
      expect(result.milestones.single.reachedAt, DateTime(2026, 9, 3, 12));
      expect(result.milestones.single.elapsedDays, 2);
    },
  );

  test(
    'rolling window can decline without decreasing cumulative crossings',
    () {
      final result = run([
        progressCard(1, {
          StudyCue.fromLanguage: [
            for (var d = 1; d <= 15; d++) review(d, d <= 5 ? 3 : 1),
          ],
        }),
      ]);
      expect(result.days.last.atTarget, 0);
      expect(result.days.last.everReached, 1);
      expect(result.milestones.length, 1);
      expect(result.days[2].atTarget, 1);
    },
  );

  test('three directions average equally, missing direction is zero', () {
    final card = progressCard(1, {
      StudyCue.fromLanguage: [for (var d = 1; d <= 5; d++) review(d, 3)],
      StudyCue.toLanguage: [review(1, 3)],
    });
    expect(
      run([
        card,
      ], directions: StudyCue.activeDirections.toSet()).days.last.atTarget,
      0,
    );
    expect(
      run(
        [card],
        target: 40,
        directions: StudyCue.activeDirections.toSet(),
      ).days.last.atTarget,
      1,
    );
    expect(
      averageRetention(card, StudyCue.activeDirections),
      closeTo(.4, 1e-9),
    );
  });

  test('inclusive threshold, unreviewed denominator, and zero target', () {
    final card = progressCard(1, {
      StudyCue.fromLanguage: [
        for (var d = 1; d <= 6; d++) review(d, d <= 3 ? 3 : 1),
      ],
    });
    final empty = progressCard(2, {});
    final result = run([card, empty]);
    expect(result.cardCount, 2);
    expect(result.days.last.atTarget, 1); // exactly 50%
    expect(run([card, empty], target: 51).days.last.atTarget, 0);
    expect(run([card, empty], target: 0).days.last.atTarget, 1);
  });

  test(
    'custom end is an as-of snapshot and median only uses period crossings',
    () {
      final cards = [
        progressCard(1, {
          StudyCue.fromLanguage: [
            for (var d = 1; d <= 12; d++) review(d, d <= 3 ? 3 : 1),
          ],
        }),
        progressCard(2, {
          StudyCue.fromLanguage: [review(5, 3), review(7, 3), review(9, 3)],
        }),
      ];
      final report = run(
        cards,
        start: DateTime(2026, 9, 4),
        end: DateTime(2026, 9, 9),
      );
      expect(report.milestones.map((m) => m.card.id), [2]);
      expect(report.medianDays, 4);
      expect(report.days.last.everReached, 2);
      expect(report.days.last.atTarget, 1);
      expect(report.cardsPerDay, closeTo(1 / 6, 1e-9));
    },
  );

  test(
    'midnight belongs to the next local calendar day; archived cue excluded',
    () {
      final result = run([
        progressCard(1, {
          StudyCue.fromLanguage: [
            review(1, 3, hour: 23),
            review(2, 3, hour: 0),
          ],
          StudyCue.transliteration: [review(1, 3)],
        }),
      ]);
      expect(result.days[0].recalls, 1);
      expect(result.days[1].recalls, 1);
      expect(result.recalls, 2);
    },
  );

  test('empty history produces a stable zero series', () {
    final result = run([], start: DateTime(2026, 9, 24));
    expect(result.days.length, 7);
    expect(result.days.last.atTarget, 0);
    expect(result.medianDays, isNull);
    expect(result.cardsPerDay, 0);
  });

  test(
    'final scores match app retention for every direction and threshold',
    () {
      final cards = [
        for (var id = 0; id < 12; id++)
          progressCard(id, {
            for (final cue in StudyCue.activeDirections)
              cue: [
                for (var day = 1; day <= 20; day++)
                  review(day, (day + id + cue.index) % 4 + 1),
              ],
          }),
      ];
      for (final cues in [
        english,
        {StudyCue.fromAudio},
        {StudyCue.toLanguage},
        StudyCue.activeDirections.toSet(),
      ]) {
        for (final threshold in [1, 33, 50, 67, 80, 90, 100]) {
          expect(
            run(cards, target: threshold, directions: cues).days.last.atTarget,
            cards
                .where(
                  (c) => averageRetention(c, cues) * 100 + 1e-9 >= threshold,
                )
                .length,
          );
        }
      }
    },
  );
}
