import 'package:nx_cards/domain/card/card_review.dart';

class StudyCard {
  const StudyCard({
    required this.id,
    required this.front,
    required this.back,
    required this.deckId,
    required this.deckName,
    required this.tags,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.stability,
    required this.difficulty,
    required this.schedulingState,
    required this.learningStep,
    required this.suspended,
    required this.reviewCount,
    required this.lapseCount,
    this.reviewHistory = const [],
    this.sourceBookId,
    this.sourceBookName,
    this.updatedAt,
  });

  final int id;
  final String front;
  final String back;
  final int deckId;
  final String deckName;
  final List<String> tags;
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;
  final double? stability;
  final double? difficulty;
  final String schedulingState;
  final int? learningStep;
  final bool suspended;
  final int reviewCount;
  final int lapseCount;
  final List<CardReview> reviewHistory;
  final int? sourceBookId;
  final String? sourceBookName;

  /// Server update time is deliberately retained for future local/remote
  /// conflict handling.
  final DateTime? updatedAt;

  bool get isNew => lastReviewedAt == null;

  bool isDueAt(DateTime now) {
    if (suspended || isNew) return false;
    final due = dueAt;
    return due == null || !due.isAfter(now.toUtc());
  }

  StudyCard copyWith({
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    double? stability,
    double? difficulty,
    String? schedulingState,
    int? learningStep,
    bool clearLearningStep = false,
    int? reviewCount,
    int? lapseCount,
    List<CardReview>? reviewHistory,
  }) {
    return StudyCard(
      id: id,
      front: front,
      back: back,
      deckId: deckId,
      deckName: deckName,
      tags: tags,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      schedulingState: schedulingState ?? this.schedulingState,
      learningStep: clearLearningStep
          ? null
          : learningStep ?? this.learningStep,
      suspended: suspended,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
      reviewHistory: reviewHistory ?? this.reviewHistory,
      sourceBookId: sourceBookId,
      sourceBookName: sourceBookName,
      updatedAt: updatedAt,
    );
  }
}
