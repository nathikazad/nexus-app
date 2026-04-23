/// What the goal compares against. The data layer maps this to
/// `selected_attribute` / `aggregation` / `metric` / `filter` in KGQL.
enum GoalSelectedAttribute {
  /// Session count (e.g. 3 workouts / week). Threshold is a whole number.
  count,

  /// Total duration. Threshold is **hours** in the app model; the mapper
  /// stores seconds in `threshold_value` with `sum` + `metric: duration`.
  duration,

  /// Compare start time. Threshold is **minutes from midnight** (0–1440);
  /// the mapper also writes a `filter` with `HH:MM:SS` when needed.
  startTime,

  /// Compare end time (e.g. wake before 7:00). Threshold is **minutes
  /// from midnight**; mapper may pair with `filter` like legacy rows.
  endTime,
}

/// Stable string for form state and tests (not necessarily equal to one KGQL `selected_attribute` row).
String goalSelectedAttributeName(GoalSelectedAttribute a) {
  switch (a) {
    case GoalSelectedAttribute.count:
      return 'count';
    case GoalSelectedAttribute.duration:
      return 'duration';
    case GoalSelectedAttribute.startTime:
      return 'start_time';
    case GoalSelectedAttribute.endTime:
      return 'end_time';
  }
}

GoalSelectedAttribute? goalSelectedAttributeByName(String? raw) {
  switch (raw) {
    case 'count':
      return GoalSelectedAttribute.count;
    case 'duration':
      return GoalSelectedAttribute.duration;
    case 'start_time':
      return GoalSelectedAttribute.startTime;
    case 'end_time':
      return GoalSelectedAttribute.endTime;
    default:
      return null;
  }
}
