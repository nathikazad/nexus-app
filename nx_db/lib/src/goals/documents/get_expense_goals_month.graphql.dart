/// GraphQL document for `get_expense_goals_month`.
const String getExpenseGoalsMonthQuery = '''
query GetExpenseGoalsMonth(\$monthStart: Date!, \$domainId: Int!, \$goalId: Int) {
  getExpenseGoalsMonth(monthStart: \$monthStart, domainId: \$domainId, goalId: \$goalId)
}
''';
