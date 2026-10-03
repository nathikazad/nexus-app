/// GraphQL document for `get_action_goals_month`.
const String getActionGoalsMonthQuery = '''
query GetActionGoalsMonth(\$monthStart: Date!, \$goalId: Int, \$domainId: Int) {
  getActionGoalsMonth(monthStart: \$monthStart, goalId: \$goalId, domainId: \$domainId)
}
''';
