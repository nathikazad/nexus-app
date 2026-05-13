/// GraphQL document for `get_expense_goals_month`.
const String getExpenseGoalsMonthQuery = '''
query GetExpenseGoalsMonth(\$monthStart: Date!, \$goalId: Int) {
  getExpenseGoalsMonth(monthStart: \$monthStart, goalId: \$goalId)
}
''';
