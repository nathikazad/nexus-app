/// GraphQL document for `get_action_goals_month_score`.
const String getActionGoalsMonthScoreQuery = '''
query GetActionGoalsMonthScore(\$monthStart: Date!, \$goalId: Int, \$domainId: Int) {
  getActionGoalsMonthScore(monthStart: \$monthStart, goalId: \$goalId, domainId: \$domainId)
}
''';
