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

int? _intFrom(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}
