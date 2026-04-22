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
}
