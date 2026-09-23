import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_cards/browser/browser_providers.dart';
import 'package:nx_cards/browser/browser.dart';
import 'package:nx_cards/scheduling/review_progression.dart';

class ReviewProgressionChange {
  const ReviewProgressionChange({
    required this.card,
    required this.status,
    required this.isReplacement,
  });

  final StudyCard card;
  final LearningStatus status;
  final bool isReplacement;
}

class ReviewProgressionPlan {
  const ReviewProgressionPlan(this.changes);

  final List<ReviewProgressionChange> changes;

  int get movedToPast =>
      changes.where((change) => change.status == LearningStatus.learnt).length;
  int get movedToCurrent => changes
      .where(
        (change) =>
            change.status == LearningStatus.learning && !change.isReplacement,
      )
      .length;
  int get replacements =>
      changes.where((change) => change.isReplacement).length;
  bool get changed => changes.isNotEmpty;
}

ReviewProgressionPlan planReviewProgression({
  required Iterable<StudyCard> reviewedCards,
  required List<StudyCard> allCards,
  required ReviewProgressionSettings settings,
  StudyScope? scope,
}) {
  if (!settings.automaticProgressionEnabled) {
    return const ReviewProgressionPlan([]);
  }
  final reviewedById = <int, StudyCard>{
    for (final card in reviewedCards) card.id: card,
  };
  final changes = <ReviewProgressionChange>[];
  final projectedStatus = <int, LearningStatus>{
    for (final card in allCards) card.id: card.learningStatus,
  };
  var promotedInScope = 0;

  for (final card in reviewedById.values) {
    final reviews = <CardReview>[
      for (final cue in StudyCue.values) ...card.reviewHistoryFor(cue),
    ]..sort((a, b) => a.reviewedAt.compareTo(b.reviewedAt));
    if (reviews.isEmpty) continue;
    final recent = reviews.skip(
      (reviews.length - settings.historyWindow).clamp(0, reviews.length),
    );
    final recalled = recent.where((review) => review.rating >= 3).length;
    final percentage = recalled * 100 / settings.historyWindow;

    if (percentage >= settings.moveToPastPercentage &&
        card.learningStatus != LearningStatus.learnt) {
      changes.add(
        ReviewProgressionChange(
          card: card,
          status: LearningStatus.learnt,
          isReplacement: false,
        ),
      );
      projectedStatus[card.id] = LearningStatus.learnt;
      if (card.learningStatus == LearningStatus.learning) {
        if (scope?.contains(card) == true) promotedInScope++;
      }
    } else if (percentage <= settings.moveToCurrentPercentage &&
        card.learningStatus != LearningStatus.learning) {
      changes.add(
        ReviewProgressionChange(
          card: card,
          status: LearningStatus.learning,
          isReplacement: false,
        ),
      );
      projectedStatus[card.id] = LearningStatus.learning;
    }
  }

  if (settings.autoReplacePromotedCards && scope != null) {
    final candidates = allCards.where(
      (card) =>
          scope.contains(card) &&
          !card.suspended &&
          projectedStatus[card.id] == LearningStatus.notStarted,
    );
    for (final card in candidates.take(promotedInScope)) {
      changes.add(
        ReviewProgressionChange(
          card: card,
          status: LearningStatus.learning,
          isReplacement: true,
        ),
      );
      projectedStatus[card.id] = LearningStatus.learning;
    }
  }
  return ReviewProgressionPlan(List.unmodifiable(changes));
}

typedef RunReviewProgression =
    Future<ReviewProgressionPlan> Function(
      Iterable<StudyCard> reviewedCards, {
      StudyScope? scope,
    });

final reviewProgressionRunnerProvider = Provider<RunReviewProgression>((ref) {
  return (reviewedCards, {scope}) async {
    final reviewed = reviewedCards.toList(growable: false);
    if (reviewed.isEmpty) return const ReviewProgressionPlan([]);
    final settings = await ref.read(reviewProgressionSettingsProvider.future);
    final dashboard = await ref.read(cardsDashboardProvider.future);
    final latestById = <int, StudyCard>{
      for (final card in reviewed) card.id: card,
    };
    final allCards = [
      for (final card in dashboard.cards) latestById[card.id] ?? card,
    ];
    final plan = planReviewProgression(
      reviewedCards: reviewed,
      allCards: allCards,
      settings: settings,
      scope: scope,
    );
    final repository = ref.read(cardLibraryProvider);
    for (final change in plan.changes) {
      await repository.setLearningStatus(change.card, change.status);
    }
    if (plan.changed) invalidateCardsData(ref);
    return plan;
  };
});
