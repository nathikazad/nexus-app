/// Which reference layout to show in [GoalDetailPage] (see `reference/partials/page-goal-detail-*.html`).
enum GoalDetailVariant {
  /// Daily count + time-attribute threshold (wake before 7am, sleep by 11pm, …).
  wake,

  /// Daily sum / duration (sleep hours, reading time, …).
  sleep,

  /// Weekly count + optional slots (gym, …).
  gym,
}
