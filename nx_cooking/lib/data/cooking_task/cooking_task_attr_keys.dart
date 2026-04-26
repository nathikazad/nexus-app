library;

const String kCookingTaskModelTypeName = 'CookingTask';

/// CookingTask.status — `planned` | `cooking` | `done` | `skipped`
const String kCookingTaskAttrStatus = 'status';

/// Inherited from Task — planned cooking day.
const String kTaskAttrDate = 'date';

/// JSON map on `for_recipe`: `{ "<item_model_id>": <bool> }`
const String kForRecipeRelationAttrIngredientChecks = 'ingredient_checks';
