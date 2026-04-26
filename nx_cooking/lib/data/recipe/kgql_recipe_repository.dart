import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nx_db/kgql.dart';
import 'package:nx_cooking/data/recipe/recipe_attr_keys.dart';
import 'package:nx_cooking/data/recipe/recipe_mapper.dart';
import 'package:nx_cooking/domain/recipe.dart';
import 'package:nx_cooking/domain/recipe_detail.dart';
import 'package:nx_cooking/domain/recipe_repository.dart';

class KgqlRecipeRepository implements RecipeRepository {
  KgqlRecipeRepository({
    required GraphQLClient client,
    required Future<ModelType> Function() loadRecipeSchema,
  })  : _client = client,
        _loadRecipeSchema = loadRecipeSchema;

  final GraphQLClient _client;
  final Future<ModelType> Function() _loadRecipeSchema;

  Map<String, dynamic> _recipeStruct(ModelType schema) {
    final base = buildKgqlStructFromSchema(schema);
    final merged = Map<String, dynamic>.from(base);
    merged[kItemModelTypeName] = {
      'id': true,
      'name': true,
      'description': true,
    };
    merged['tags'] = true;
    merged['relations'] = {
      'relation_id': true,
      'model_id': true,
      'model_type': true,
    };
    return merged;
  }

  @override
  Future<List<RecipeSummary>> fetchRecipes() async {
    final schema = await _loadRecipeSchema();
    final struct = _recipeStruct(schema);
    final models = await fetchKgqlModels(
      _client,
      filter: {'model_type': kRecipeModelTypeName},
      struct: struct,
    );
    return models.map(recipeSummaryFromModel).toList();
  }

  @override
  Future<RecipeDetail?> fetchRecipeDetail(int id) async {
    final schema = await _loadRecipeSchema();
    final struct = _recipeStruct(schema);
    final m = await fetchKgqlModelById(
      _client,
      modelTypeName: kRecipeModelTypeName,
      id: id,
      struct: struct,
    );
    return m == null ? null : recipeDetailFromModel(m);
  }

  @override
  Future<int> createRecipe(RecipeFormData form) async {
    final req = setRequestForCreateRecipe(form);
    return setKgqlModel(_client, req);
  }

  @override
  Future<void> updateRecipe(int id, RecipeFormData form) async {
    final previous = await fetchRecipeDetail(id);
    if (previous == null) {
      throw StateError('Recipe $id not found');
    }
    final req = setRequestForUpdateRecipeWithIngredients(id, form, previous);
    await setKgqlModel(_client, req);
  }

  @override
  Future<void> deleteRecipe(int id) async {
    await setKgqlModel(_client, setRequestForDeleteRecipe(id));
  }
}
