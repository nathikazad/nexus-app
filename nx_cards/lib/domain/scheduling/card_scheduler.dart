import 'dart:math';

import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:nx_cards/domain/cards_models.dart';

class ScheduledOutcome {
  const ScheduledOutcome({required this.card, required this.interval});

  final StudyCard card;
  final Duration interval;
}

abstract class CardScheduler {
  Map<CardRating, ScheduledOutcome> preview(StudyPrompt prompt, DateTime now);
}

class FsrsCardScheduler implements CardScheduler {
  FsrsCardScheduler({fsrs.Scheduler? scheduler, String Function()? reviewId})
    : _scheduler =
          scheduler ??
          fsrs.Scheduler(desiredRetention: 0.9, enableFuzzing: false),
      _reviewId = reviewId ?? _newReviewId;

  final fsrs.Scheduler _scheduler;
  final String Function() _reviewId;

  @override
  Map<CardRating, ScheduledOutcome> preview(StudyPrompt prompt, DateTime now) {
    final reviewedAt = now.toUtc();
    return {
      for (final rating in CardRating.values)
        rating: _schedule(prompt, rating, reviewedAt),
    };
  }

  ScheduledOutcome _schedule(
    StudyPrompt prompt,
    CardRating rating,
    DateTime reviewedAt,
  ) {
    final source = prompt.schedule;
    final input = fsrs.Card(
      cardId: prompt.cardId * StudyCue.values.length + prompt.cue.index,
      state: _stateFromString(source.schedulingState),
      step: source.learningStep,
      stability: source.stability,
      difficulty: source.difficulty,
      due: source.dueAt?.toUtc() ?? reviewedAt,
      lastReview: source.lastReviewedAt?.toUtc(),
    );
    final result = _scheduler.reviewCard(
      input,
      _ratingToFsrs(rating),
      reviewDateTime: reviewedAt,
    );
    final next = result.card;
    final lapsed = rating == CardRating.again && !prompt.isNew;
    final interval = next.due.difference(reviewedAt);
    final elapsed = source.lastReviewedAt == null
        ? Duration.zero
        : reviewedAt.difference(source.lastReviewedAt!.toUtc());
    final review = CardReview(
      id: _reviewId(),
      reviewedAt: reviewedAt,
      rating: rating.fsrsValue,
      elapsedSeconds: max(0, elapsed.inSeconds),
      scheduledSeconds: max(0, interval.inSeconds),
    );
    return ScheduledOutcome(
      card: prompt.card.updateCue(
        cue: prompt.cue,
        schedule: source.copyWith(
          dueAt: next.due.toUtc(),
          lastReviewedAt: reviewedAt,
          stability: next.stability,
          difficulty: next.difficulty,
          schedulingState: next.state.name,
          learningStep: next.step,
          clearLearningStep: next.step == null,
          reviewCount: source.reviewCount + 1,
          lapseCount: source.lapseCount + (lapsed ? 1 : 0),
        ),
        history: [...prompt.reviewHistory, review],
      ),
      interval: interval,
    );
  }
}

String _newReviewId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

fsrs.State _stateFromString(String value) {
  return switch (value) {
    'review' => fsrs.State.review,
    'relearning' => fsrs.State.relearning,
    _ => fsrs.State.learning,
  };
}

fsrs.Rating _ratingToFsrs(CardRating rating) {
  return switch (rating) {
    CardRating.again => fsrs.Rating.again,
    CardRating.hard => fsrs.Rating.hard,
    CardRating.good => fsrs.Rating.good,
    CardRating.easy => fsrs.Rating.easy,
  };
}

String formatInterval(Duration duration) {
  if (duration.inMinutes < 1) return '< 1 min';
  if (duration.inMinutes < 60) return '${duration.inMinutes} min';
  if (duration.inHours < 24) return '${duration.inHours} hr';
  if (duration.inDays < 30) return '${duration.inDays} days';
  final months = (duration.inDays / 30).round();
  if (months < 12) return '$months mo';
  return '${(duration.inDays / 365).toStringAsFixed(1)} yr';
}
