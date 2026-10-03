/// GraphQL document for `get_action_goals_week`.
const String getActionGoalsWeekQuery = '''
query GetActionGoalsWeek(\$weekStart: Date!, \$goalId: Int, \$domainId: Int) {
  getActionGoalsWeek(weekStart: \$weekStart, goalId: \$goalId, domainId: \$domainId)
}
''';
