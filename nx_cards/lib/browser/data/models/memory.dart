class CardReview {
  const CardReview({
    required this.id,
    required this.reviewedAt,
    required this.rating,
    required this.elapsedSeconds,
    required this.scheduledSeconds,
  });

  final String id;
  final DateTime reviewedAt;

  /// FSRS rating: 1 = Again, 2 = Hard, 3 = Good, 4 = Easy.
  final int rating;
  final int elapsedSeconds;
  final int scheduledSeconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    'rating': rating,
    'elapsed_seconds': elapsedSeconds,
    'scheduled_seconds': scheduledSeconds,
  };

  static CardReview? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final id = json['id']?.toString();
    final reviewedAt = DateTime.tryParse(json['reviewed_at']?.toString() ?? '');
    final rating = _intFrom(json['rating']);
    if (id == null ||
        id.isEmpty ||
        reviewedAt == null ||
        rating == null ||
        rating < 1 ||
        rating > 4) {
      return null;
    }
    return CardReview(
      id: id,
      reviewedAt: reviewedAt.toUtc(),
      rating: rating,
      elapsedSeconds: _intFrom(json['elapsed_seconds']) ?? 0,
      scheduledSeconds: _intFrom(json['scheduled_seconds']) ?? 0,
    );
  }
}

enum CardRating { again, hard, good, easy }

extension CardRatingValue on CardRating {
  int get fsrsValue => index + 1;
}

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

int? _intFrom(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}
