import 'package:nx_db/riverpod.dart';

import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';

/// Cached [ModelType] for Recipe (schema for struct + writes).
final recipeSchemaProvider = modelTypeByNameProvider(kRecipeModelTypeName);
