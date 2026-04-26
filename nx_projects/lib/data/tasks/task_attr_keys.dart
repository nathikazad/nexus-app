/// KGQL / attribute names for [ProjectTask] descendants.
library;

const String kTaskBaseModelTypeName = 'ProjectTask';
const String kFeatureModelTypeName = 'Feature';
const String kBugModelTypeName = 'Bug';

const String kTaskAttrPriority = 'priority';
const String kTaskAttrStatus = 'status';
const String kTaskAttrEstimateHours = 'estimate_hours';
const String kTaskAttrDate = 'date';
const String kTaskAttrSeverity = 'severity';

/// [Feature] only; see `ideation_status` in PG.
const String kTaskAttrIdeationStatus = 'ideation_status';

/// Nested [Project] from `in_project` uses this struct key in responses.
const String kTaskProjectLinkKey = 'Project';

/// Nested [Sprint] from `in_sprint` uses this struct key; matches [ModelType] name.
const String kTaskSprintLinkKey = 'Sprint';
