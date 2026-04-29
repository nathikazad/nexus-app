/// GraphQL document for `get_action_goals_week`.
const String getActionGoalsWeekQuery = '''
query GetActionGoalsWeek(\$weekStart: Date!, \$domainId: Int!, \$goalId: Int) {
  getActionGoalsWeek(weekStart: \$weekStart, domainId: \$domainId, goalId: \$goalId)
}
''';
