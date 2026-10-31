import 'package:nx_db/kgql.dart';

/// The shared activity selection and validity period for goals and a schedule.
class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.modelType,
    required this.startDate,
    this.endDate,
    this.filter,
    this.goals = const [],
    this.schedule,
  });
  final int id;
  final String name, modelType, startDate;
  final String? endDate;
  final Map<String, dynamic>? filter;
  final List<Model> goals;
  final Model? schedule;

  static Routine linkedTo(Model model) {
    final rows = model.relations?['Routine'] ?? const <Model>[];
    if (rows.length != 1) {
      throw StateError('${model.name} must have one Routine');
    }
    return Routine.fromModel(rows.single);
  }

  factory Routine.fromModel(Model model) {
    final a = model.attributes ?? {};
    final schedules = model.relations?['Schedule'] ?? const <Model>[];
    if (schedules.length > 1) {
      throw StateError('Routine has multiple schedules');
    }
    return Routine(
      id: model.id,
      name: model.name,
      modelType: a['model_type'] as String,
      startDate: a['start_date'] as String,
      endDate: a['end_date'] as String?,
      filter: (a['filter'] as Map?)?.cast<String, dynamic>(),
      goals: model.relations?['Goal'] ?? const [],
      schedule: schedules.isEmpty ? null : schedules.single,
    );
  }
}
