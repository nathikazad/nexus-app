import 'dart:convert';
import 'package:nx_db/goals.dart' as wire;
import 'package:nx_db/kgql.dart';
import 'package:nx_time/data/goals/goal_mapper.dart';
import 'package:nx_time/dev/scheduled_routine_fixture.dart';
import 'package:nx_time/domain/schedules/schedule_plan.dart';
import 'package:nx_time/features/routine/routine_data.dart';

RoutineData previewRoutine() {
  final json = jsonDecode(scheduledRoutineJson) as Map<String, dynamic>;
  return RoutineData(
    goals: actionGoalsMonthFromWire(
      wire.ActionGoalMonthResponse.fromJson(
        json['goals'] as Map<String, dynamic>,
      ),
    ).items,
    plans: (json['plans'] as List)
        .map(
          (p) =>
              SchedulePlan.fromModel(Model.fromJson(p as Map<String, dynamic>)),
        )
        .toList(),
  );
}
