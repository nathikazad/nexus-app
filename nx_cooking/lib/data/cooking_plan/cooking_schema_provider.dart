import 'package:nx_db/riverpod.dart';
import 'package:nx_cooking/data/cooking_plan/cooking_plan_attr_keys.dart';

/// Cached [ModelType] for Cooking (struct + writes) in the **home** domain.
final cookingSchemaProvider = kgqlModelTypeByNameProvider(
  kCookingModelTypeName,
);
