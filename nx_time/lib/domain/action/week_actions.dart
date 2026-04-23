import 'package:nx_time/domain/action/action.dart';

/// All [Action]s for a single calendar week, grouped by local overlap day.
///
/// [byDay][0] is Monday … [6] is Sunday. [all] is the de-duplicated fetch list.
class WeekActions {
  const WeekActions({
    required this.weekStart,
    required this.byDay,
    required this.all,
  });

  final DateTime weekStart;
  final List<List<Action>> byDay;
  final List<Action> all;
}
