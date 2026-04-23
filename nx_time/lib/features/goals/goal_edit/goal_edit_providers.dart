import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nx_time/data/providers.dart';

/// One pickable action subtype (Sleep, Workout, …) for [Goal.model_type].
class GoalActionTypeOption {
  const GoalActionTypeOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// Same list as the action create screen — from KGQL `Action` descendants.
final goalActionTypeOptionsProvider =
    FutureProvider<List<GoalActionTypeOption>>((ref) async {
  final subtypes = await ref.watch(actionSubtypeModelTypesProvider.future);
  return subtypes
      .map(
        (e) => GoalActionTypeOption(
          id: e.id,
          name: e.name,
        ),
      )
      .toList();
});
