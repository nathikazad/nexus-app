class ActionGoalSchedule {
  const ActionGoalSchedule({this.id, this.entries = const []});
  final int? id;
  final List<Map<String, dynamic>> entries;
  List<String> get days => entries
      .expand((e) => (e['days'] as List).cast<String>())
      .toSet()
      .toList();
  factory ActionGoalSchedule.fromJson(Map<String, dynamic> json) =>
      ActionGoalSchedule(
        id: (json['id'] as num?)?.toInt(),
        entries: (json['entries'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
  Map<String, dynamic> toJson() => {'id': id, 'entries': entries};
}
