/// GraphQL document for `get_action_goals_trend`.
const String getActionGoalsTrendQuery = '''
query GetActionGoalsTrend(\$goalId: Int!, \$weeks: Int!, \$domainId: Int!) {
  getActionGoalsTrend(goalId: \$goalId, weeks: \$weeks, domainId: \$domainId)
}
''';
