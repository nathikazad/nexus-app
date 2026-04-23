import 'package:nx_db/riverpod.dart';

import 'package:nx_time/data/goals/goal_attr_keys.dart';

/// Cached [ModelType] for [Goal] (from [get_kgql_model_type]).
final goalSchemaProvider = modelTypeByNameProvider(kGoalModelTypeName);
