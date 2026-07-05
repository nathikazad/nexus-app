class ActionGoalMeta {
  const ActionGoalMeta({
    this.dueDays,
  });

  final List<String>? dueDays;

  factory ActionGoalMeta.fromJson(Map<String, dynamic> json) {
    List<String>? dueDays;
    final raw = json['due_days'];
    if (raw is List) {
      dueDays = raw
          .map((e) => e?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return ActionGoalMeta(
      dueDays: dueDays,
    );
  }

  Map<String, dynamic> toJson() => {
        if (dueDays != null) 'due_days': dueDays,
      };
}
