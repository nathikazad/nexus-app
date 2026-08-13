import '../goal_parsing.dart';

class ActionGoalTrendBucket {
  const ActionGoalTrendBucket({
    required this.periodStart,
    required this.successes,
    required this.expected,
    required this.hit,
  });

  final DateTime periodStart;
  final num successes;
  final num expected;
  final bool hit;

  factory ActionGoalTrendBucket.fromJson(Map<String, dynamic> json) {
    final ps = parseDateOnly(json['period_start']);
    if (ps == null) {
      throw FormatException('ActionGoalTrendBucket: missing period_start');
    }
    return ActionGoalTrendBucket(
      periodStart: ps,
      successes: json['successes'] as num? ?? 0,
      expected: json['expected'] as num? ?? 0,
      hit: json['hit'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'period_start': periodStart.toIso8601String().split('T').first,
        'successes': successes,
        'expected': expected,
        'hit': hit,
      };
}

class ActionGoalTrendResponse {
  const ActionGoalTrendResponse({
    this.goalId,
    this.cadence,
    this.weeks,
    required this.buckets,
  });

  final int? goalId;
  final String? cadence;
  final int? weeks;
  final List<ActionGoalTrendBucket> buckets;

  factory ActionGoalTrendResponse.fromJson(Map<String, dynamic> json) {
    final rawBuckets = json['buckets'] as List<dynamic>?;
    final buckets = (rawBuckets ?? const [])
        .map((e) {
          if (e is Map<String, dynamic>) {
            return ActionGoalTrendBucket.fromJson(e);
          }
          if (e is Map) {
            return ActionGoalTrendBucket.fromJson(
              Map<String, dynamic>.from(e),
            );
          }
          return null;
        })
        .whereType<ActionGoalTrendBucket>()
        .toList();
    return ActionGoalTrendResponse(
      goalId: (json['goal_id'] as num?)?.toInt(),
      cadence: json['cadence'] as String?,
      weeks: (json['weeks'] as num?)?.toInt(),
      buckets: buckets,
    );
  }

  /// When the server returns only `{ "buckets": [] }` (goal not found).
  factory ActionGoalTrendResponse.bucketsOnlyEmpty() {
    return const ActionGoalTrendResponse(buckets: []);
  }

  Map<String, dynamic> toJson() => {
        if (goalId != null) 'goal_id': goalId,
        if (cadence != null) 'cadence': cadence,
        if (weeks != null) 'weeks': weeks,
        'buckets': buckets.map((e) => e.toJson()).toList(),
      };
}
