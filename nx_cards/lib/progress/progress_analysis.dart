import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/learning_stage.dart';

DateTime progressDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime nextProgressDay(DateTime day) =>
    DateTime(day.year, day.month, day.day + 1);

class ProgressDay {
  const ProgressDay(this.date, this.atTarget, this.everReached, this.recalls);
  final DateTime date;
  final int atTarget;
  final int everReached;
  final int recalls;
}

class ProgressMilestone {
  const ProgressMilestone(this.card, this.startedAt, this.reachedAt);
  final StudyCard card;
  final DateTime startedAt;
  final DateTime reachedAt;
  double get elapsedDays =>
      reachedAt.difference(startedAt).inSeconds / Duration.secondsPerDay;
}

class ProgressAnalysis {
  const ProgressAnalysis({
    required this.days,
    required this.milestones,
    required this.cardCount,
    required this.reviewedCount,
    required this.firstReview,
    required this.firstAudioReview,
    this.openingCount = 0,
  });
  final List<ProgressDay> days;

  /// First crossings within the displayed period, newest first.
  final List<ProgressMilestone> milestones;
  final int cardCount;
  final int reviewedCount;
  final DateTime? firstReview;
  final DateTime? firstAudioReview;
  final int openingCount;
  int get recalls => days.fold(0, (sum, day) => sum + day.recalls);
  double get cardsPerDay => milestones.length / days.length;
  double? get medianDays {
    if (milestones.isEmpty) return null;
    final values = milestones.map((m) => m.elapsedDays).toList()..sort();
    final middle = values.length ~/ 2;
    return values.length.isOdd
        ? values[middle]
        : (values[middle - 1] + values[middle]) / 2;
  }
}

typedef _Event = ({StudyCard card, StudyCue cue, CardReview review});

/// Replay full histories before clipping to the visible date range. Current
/// category membership is fixed across the timeline, including backlog cards.
/// No historical workflow status or category membership is inferred.
ProgressAnalysis analyzeProgress({
  required List<StudyCard> cards,
  required Set<StudyCue> directions,
  required int targetPercent,
  required DateTime now,
  DateTime? start,
  DateTime? end,
}) {
  assert(directions.isNotEmpty);
  assert(targetPercent >= 0 && targetPercent <= 100);
  final lastDay = progressDay(end == null || end.isAfter(now) ? now : end);
  final events = <_Event>[];
  DateTime? firstAudio;
  for (final card in cards) {
    for (final cue in StudyCue.activeDirections) {
      final unique = {for (final r in card.reviewHistoryFor(cue)) r.id: r};
      for (final review in unique.values) {
        if (review.reviewedAt.isAfter(now) ||
            !review.reviewedAt.isBefore(nextProgressDay(lastDay))) {
          continue;
        }
        if (cue == StudyCue.fromAudio &&
            (firstAudio == null || review.reviewedAt.isBefore(firstAudio))) {
          firstAudio = review.reviewedAt;
        }
        if (directions.contains(cue)) {
          events.add((card: card, cue: cue, review: review));
        }
      }
    }
  }
  events.sort((a, b) {
    final byTime = a.review.reviewedAt.compareTo(b.review.reviewedAt);
    if (byTime != 0) return byTime;
    final byId = a.review.id.compareTo(b.review.id);
    if (byId != 0) return byId;
    final byCard = a.card.id.compareTo(b.card.id);
    return byCard != 0 ? byCard : a.cue.index.compareTo(b.cue.index);
  });
  final first = events.firstOrNull?.review.reviewedAt;
  final requestedStart = progressDay(start ?? first ?? lastDay);
  final firstDay = requestedStart.isAfter(lastDay) ? lastDay : requestedStart;
  final history = <(int, StudyCue), List<CardReview>>{};
  final started = <int, DateTime>{};
  final reached = <int, ProgressMilestone>{};
  final atTarget = <int>{};
  final counts = <DateTime, int>{};
  var cursor = 0;
  var openingCount = 0;
  final days = <ProgressDay>[];
  for (var day = firstDay; !day.isAfter(lastDay); day = nextProgressDay(day)) {
    final boundary = nextProgressDay(day);
    while (cursor < events.length &&
        events[cursor].review.reviewedAt.isBefore(boundary)) {
      final event = events[cursor++];
      final id = event.card.id;
      final time = event.review.reviewedAt;
      started.putIfAbsent(id, () => time);
      final window = history.putIfAbsent((id, event.cue), () => []);
      window.add(event.review);
      if (window.length > 10) window.removeAt(0);
      final effectiveDirections = directions
          .where(event.card.studiesCue)
          .toList();
      final average = effectiveDirections.isEmpty
          ? 0.0
          : effectiveDirections
                    .map((cue) {
                      final reviews =
                          history[(id, cue)] ?? const <CardReview>[];
                      return RecallScore(
                        recalled: reviews.where((r) => r.rating >= 3).length,
                        attempts: reviews.length,
                      ).fraction;
                    })
                    .reduce((a, b) => a + b) /
                effectiveDirections.length;
      if (effectiveDirections.isNotEmpty &&
          average * 100 + 1e-9 >= targetPercent) {
        atTarget.add(id);
        reached.putIfAbsent(
          id,
          () => ProgressMilestone(event.card, started[id]!, time),
        );
      } else {
        atTarget.remove(id);
      }
      final date = progressDay(time);
      if (time.isBefore(firstDay)) openingCount = atTarget.length;
      counts[date] = (counts[date] ?? 0) + 1;
    }
    days.add(
      ProgressDay(day, atTarget.length, reached.length, counts[day] ?? 0),
    );
  }
  final milestones =
      reached.values.where((m) => !m.reachedAt.isBefore(firstDay)).toList()
        ..sort((a, b) => b.reachedAt.compareTo(a.reachedAt));
  return ProgressAnalysis(
    days: days,
    milestones: milestones,
    cardCount: cards.length,
    reviewedCount: started.length,
    firstReview: first,
    firstAudioReview: firstAudio,
    openingCount: openingCount,
  );
}

enum ProgressInterval { day, week, month }

class ProgressBucket extends ProgressDay {
  const ProgressBucket({
    required this.start,
    required DateTime end,
    required int atTarget,
    required int recalls,
    required this.change,
    required this.partial,
  }) : super(end, atTarget, 0, recalls);
  final DateTime start;
  final int change;
  final bool partial;
}

/// Monday-based calendar weeks and calendar months. Totals include only the
/// selected date range; balances carry forward from before that range.
List<ProgressBucket> groupProgress(
  ProgressAnalysis report,
  ProgressInterval interval,
  DateTime now,
) {
  DateTime key(DateTime day) => switch (interval) {
    ProgressInterval.day => day,
    ProgressInterval.week => DateTime(
      day.year,
      day.month,
      day.day - day.weekday + 1,
    ),
    ProgressInterval.month => DateTime(day.year, day.month),
  };
  final groups = <DateTime, List<ProgressDay>>{};
  for (final day in report.days) {
    groups.putIfAbsent(key(day.date), () => []).add(day);
  }
  var previous = report.openingCount;
  return [
    for (final entry in groups.entries)
      (() {
        final days = entry.value;
        final fullEnd = switch (interval) {
          ProgressInterval.day => entry.key,
          ProgressInterval.week => DateTime(
            entry.key.year,
            entry.key.month,
            entry.key.day + 6,
          ),
          ProgressInterval.month => DateTime(
            entry.key.year,
            entry.key.month + 1,
            0,
          ),
        };
        final change = days.last.atTarget - previous;
        previous = days.last.atTarget;
        return ProgressBucket(
          start: days.first.date,
          end: days.last.date,
          atTarget: days.last.atTarget,
          recalls: days.fold(0, (sum, d) => sum + d.recalls),
          change: change,
          partial:
              days.first.date != entry.key ||
              days.last.date != fullEnd ||
              days.last.date == progressDay(now),
        );
      })(),
  ];
}
