import 'package:flutter_test/flutter_test.dart';
import 'package:nx_cards/scheduling/review_progression.dart';
import 'package:nx_cards/scheduling/review_progression_service.dart';
import 'learning_stage_test.dart' show card;

void main() {
  test(
    'review completion never changes activation or promotes a future replacement',
    () {
      final c = card(List.filled(10, 3));
      final future = card([], active: false);
      final plan = planReviewProgression(
        reviewedCards: [c],
        allCards: [c, future],
        settings: const ReviewProgressionSettings(),
      );
      expect(plan.changes, isEmpty);
      expect(future.active, isFalse);
    },
  );
}
