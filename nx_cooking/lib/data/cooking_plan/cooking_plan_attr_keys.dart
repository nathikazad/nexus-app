library;

const String kCookingModelTypeName = 'Cooking';

/// Plannable.planning_status — `planned` | `attended` | `skipped` | `cancelled`.
const String kCookingAttrPlanningStatus = 'planning_status';

const String kCookingPlanningStatusPlanned = 'planned';
const String kCookingPlanningStatusAttended = 'attended';
const String kCookingPlanningStatusSkipped = 'skipped';
const String kCookingPlanningStatusCancelled = 'cancelled';

/// Plannable scheduled start for this planned cooking session.
const String kCookingAttrScheduledStartTime = 'scheduled_start_time';

/// Plannable scheduled end, currently optional in the cooking UI.
const String kCookingAttrScheduledEndTime = 'scheduled_end_time';

/// JSON map on `cooks_recipe`: `{ "<item_model_id>": <bool> }`
const String kCooksRecipeRelationAttrIngredientChecks = 'ingredient_checks';
