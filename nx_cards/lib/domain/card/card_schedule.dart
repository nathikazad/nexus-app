class CardSchedule {
  const CardSchedule({
    required this.enabled,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.stability,
    required this.difficulty,
    required this.schedulingState,
    required this.learningStep,
    required this.reviewCount,
    required this.lapseCount,
  });

  const CardSchedule.initial({required bool enabled})
    : this(
        enabled: enabled,
        dueAt: null,
        lastReviewedAt: null,
        stability: null,
        difficulty: null,
        schedulingState: 'learning',
        learningStep: 0,
        reviewCount: 0,
        lapseCount: 0,
      );

  final bool enabled;
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;
  final double? stability;
  final double? difficulty;
  final String schedulingState;
  final int? learningStep;
  final int reviewCount;
  final int lapseCount;

  bool get isNew => lastReviewedAt == null;

  bool isDueAt(DateTime now) {
    if (!enabled || isNew) return false;
    final due = dueAt;
    return due == null || !due.isAfter(now.toUtc());
  }

  CardSchedule copyWith({
    bool? enabled,
    DateTime? dueAt,
    bool clearDueAt = false,
    DateTime? lastReviewedAt,
    double? stability,
    double? difficulty,
    String? schedulingState,
    int? learningStep,
    bool clearLearningStep = false,
    int? reviewCount,
    int? lapseCount,
  }) {
    return CardSchedule(
      enabled: enabled ?? this.enabled,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      schedulingState: schedulingState ?? this.schedulingState,
      learningStep: clearLearningStep
          ? null
          : learningStep ?? this.learningStep,
      reviewCount: reviewCount ?? this.reviewCount,
      lapseCount: lapseCount ?? this.lapseCount,
    );
  }
}
