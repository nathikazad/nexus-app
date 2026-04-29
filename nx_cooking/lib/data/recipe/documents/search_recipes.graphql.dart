/// PostGraphile root query for `app.search_recipes`.
const String searchRecipesQuery = '''
query SearchRecipes(\$searchTerm: String!, \$domainId: Int!, \$limitPer: Int) {
  searchRecipes(searchTerm: \$searchTerm, domainId: \$domainId, limitPer: \$limitPer)
}
''';
