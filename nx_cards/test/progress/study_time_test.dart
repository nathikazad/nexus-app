import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/progress/progress_analysis.dart';
import 'package:nx_cards/progress/study_time.dart';
import 'progress_analysis_test.dart' show progressCard;

CardReview at(DateTime time, [String? id]) => CardReview(
  id: id ?? time.toIso8601String(),
  reviewedAt: time,
  rating: 3,
  elapsedSeconds: 0,
  scheduledSeconds: 0,
);

void main() {
  final day = DateTime(2026, 10, 27);
  final noon = day.add(const Duration(hours: 12));
  final cue = StudyCue.languageDirections.first;

  test(
    'deduplicates directional reviews and ignores credits and future events',
    () {
      final cards = [
        progressCard(1, {
          for (final direction in StudyCue.languageDirections)
            direction: [
              at(noon),
              at(noon.add(const Duration(milliseconds: 500))),
              at(noon.add(const Duration(seconds: 20))),
              at(noon.add(const Duration(seconds: 40)), 'phrase/1/credit'),
              at(noon.add(const Duration(days: 1))),
            ],
        }),
      ];
      expect(
        estimatedStudyTime(cards, now: noon.add(const Duration(hours: 1)))[day],
        const Duration(seconds: 40),
      );
    },
  );

  test('caps slow gaps and excludes breaks between sessions', () {
    final cards = [
      progressCard(1, {
        cue: [
          at(noon),
          at(noon.add(const Duration(seconds: 20))),
          at(noon.add(const Duration(minutes: 4))),
          at(noon.add(const Duration(hours: 2))),
        ],
      }),
    ];
    expect(
      estimatedStudyTime(cards, now: noon.add(const Duration(hours: 3)))[day],
      const Duration(seconds: 150),
    );
  });

  test('splits midnight and goal calculation agrees with full progress', () {
    final midnight = DateTime(2026, 10, 28);
    final cards = [
      progressCard(1, {
        cue: [
          at(midnight.subtract(const Duration(seconds: 10))),
          at(midnight.add(const Duration(seconds: 10))),
          at(midnight.add(const Duration(seconds: 30))),
        ],
      }),
    ];
    final now = midnight.add(const Duration(hours: 1));
    final full = estimatedStudyTime(cards, now: now);
    expect(full[day], const Duration(seconds: 40));
    expect(full[midnight], const Duration(seconds: 30));
    expect(
      estimatedStudyTime(cards, now: now, start: midnight)[midnight],
      full[midnight],
    );
  });

  test('daily, weekly, monthly and date range totals agree', () {
    final now = DateTime(2026, 10, 28, 23);
    final cards = [
      progressCard(1, {
        cue: [
          at(DateTime(2026, 9, 30, 12)),
          at(noon),
          at(DateTime(2026, 10, 28, 12)),
        ],
      }),
    ];
    final report = analyzeProgress(
      cards: cards,
      directions: RecallComponent.values.toSet(),
      targetPercent: 50,
      now: now,
    );
    expect(report.studyTime, const Duration(seconds: 90));
    for (final interval in ProgressInterval.values) {
      expect(
        groupProgress(
          report,
          interval,
          now,
        ).fold(Duration.zero, (sum, bucket) => sum + bucket.studyTime),
        report.studyTime,
      );
    }
    final clipped = analyzeProgress(
      cards: cards,
      directions: RecallComponent.values.toSet(),
      targetPercent: 50,
      now: now,
      start: day,
    );
    expect(clipped.studyTime, const Duration(seconds: 60));
  });

  test('empty history and readable duration labels', () {
    expect(estimatedStudyTime([], now: noon), isEmpty);
    expect(formatStudyTime(Duration.zero), '0 min');
    expect(formatStudyTime(const Duration(seconds: 30)), '<1 min');
    expect(formatStudyTime(const Duration(minutes: 73)), '1h 13m');
  });
}
