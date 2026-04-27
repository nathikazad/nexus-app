/// KGQL model type names and Recipe / Item attribute keys.
library;

const String kRecipeModelTypeName = 'Recipe';

const String kItemModelTypeName = 'Item';

const String kRecipeAttrPrepTime = 'prep_time';

const String kRecipeAttrServings = 'servings';

const String kRecipeAttrInstructions = 'instructions';

/// Full crawler `RecipeExtraction` payload (json attribute on Recipe).
const String kRecipeAttrCrawlerPayload = 'crawler_payload';

const String kHasIngredientRelationAttrQuantity = 'quantity';

const String kHasIngredientRelationAttrGroupName = 'group_name';

const String kHasIngredientRelationAttrNotes = 'notes';
