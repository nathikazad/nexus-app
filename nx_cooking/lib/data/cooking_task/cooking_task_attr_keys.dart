library;

const String kCookingTaskModelTypeName = 'CookingTask';

/// CookingTask.status — `planned` | `cooking` | `done` | `skipped`
const String kCookingTaskAttrStatus = 'status';

/// Free-form notes on this planned meal (CookingTask model attribute).
const String kCookingTaskAttrNotes = 'notes';

/// Inherited from Task — planned cooking day.
const String kTaskAttrDate = 'date';

/// JSON map on `for_recipe`: `{ "<item_model_id>": <bool> }`
const String kForRecipeRelationAttrIngredientChecks = 'ingredient_checks';
