import 'package:nx_cards/scheduling/study_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  int get movedToPast => 0;
  int get movedToCurrent => changes
      .where(
        (change) =>
            change.status == LearningStatus.active && !change.isReplacement,
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
  return const ReviewProgressionPlan([]);
}

typedef RunReviewProgression =
    Future<ReviewProgressionPlan> Function(
      Iterable<StudyCard> reviewedCards, {
      StudyScope? scope,
    });

final reviewProgressionRunnerProvider = Provider<RunReviewProgression>((ref) {
  return (reviewedCards, {scope}) async => const ReviewProgressionPlan([]);
});
