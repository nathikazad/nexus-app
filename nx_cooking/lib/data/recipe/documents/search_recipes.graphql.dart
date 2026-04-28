/// PostGraphile root query for `app.search_recipes(search_term, limit_per)`.
const String searchRecipesQuery = '''
query SearchRecipes(\$searchTerm: String!, \$limitPer: Int) {
  searchRecipes(searchTerm: \$searchTerm, limitPer: \$limitPer)
}
''';
