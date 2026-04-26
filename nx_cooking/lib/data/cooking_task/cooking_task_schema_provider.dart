import 'package:nx_db/riverpod.dart';
import 'package:nx_cooking/data/cooking_task/cooking_task_attr_keys.dart';

/// Cached [ModelType] for CookingTask (struct + writes).
final cookingTaskSchemaProvider = modelTypeByNameProvider(
  kCookingTaskModelTypeName,
);
