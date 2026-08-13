/// GraphQL document for `get_action_goals_month`.
const String getActionGoalsMonthQuery = '''
query GetActionGoalsMonth(\$monthStart: Date!, \$goalId: Int) {
  getActionGoalsMonth(monthStart: \$monthStart, goalId: \$goalId)
}
''';
