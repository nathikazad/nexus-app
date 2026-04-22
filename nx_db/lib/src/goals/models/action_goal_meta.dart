import 'goal_preferred_slot.dart';

class ActionGoalMeta {
  const ActionGoalMeta({
    this.preferredSlots,
    this.autoGenerateTasks,
  });

  final List<GoalPreferredSlot>? preferredSlots;
  final bool? autoGenerateTasks;

  factory ActionGoalMeta.fromJson(Map<String, dynamic> json) {
    List<GoalPreferredSlot>? slots;
    final raw = json['preferred_slots'];
    if (raw is List) {
      slots = raw
          .map((e) {
            if (e is Map<String, dynamic>) {
              return GoalPreferredSlot.fromJson(e);
            }
            if (e is Map) {
              return GoalPreferredSlot.fromJson(Map<String, dynamic>.from(e));
            }
            return null;
          })
          .whereType<GoalPreferredSlot>()
          .toList();
    }
    return ActionGoalMeta(
      preferredSlots: slots,
      autoGenerateTasks: json['auto_generate_tasks'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (preferredSlots != null)
          'preferred_slots': preferredSlots!.map((e) => e.toJson()).toList(),
        if (autoGenerateTasks != null) 'auto_generate_tasks': autoGenerateTasks,
      };
}
