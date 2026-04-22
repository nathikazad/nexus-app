class GoalPreferredSlot {
  const GoalPreferredSlot({
    required this.dow,
    required this.startTime,
    required this.durationMin,
    this.hit,
  });

  final String dow;
  final String startTime;
  final int durationMin;
  final bool? hit;

  factory GoalPreferredSlot.fromJson(Map<String, dynamic> json) {
    return GoalPreferredSlot(
      dow: json['dow'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 0,
      hit: json['hit'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'dow': dow,
        'start_time': startTime,
        'duration_min': durationMin,
        if (hit != null) 'hit': hit,
      };
}
