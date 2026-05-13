/// PostGraphile root query for `app.search_recipes`.
const String searchRecipesQuery = '''
query SearchRecipes(\$searchTerm: String!, \$limitPer: Int) {
  searchRecipes(searchTerm: \$searchTerm, limitPer: \$limitPer)
}
''';
