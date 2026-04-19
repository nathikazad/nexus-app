/// KGQL / attribute keys for Action rows — only the data layer imports these.
///
/// [kActionModelTypeName] is the abstract Action type: `get_kgql_models` with
/// `model_type: Action` returns rows for Action and all concrete descendants.
library;

const String kActionModelTypeName = 'Action';

const String kActionAttrStartTime = 'start_time';
const String kActionAttrEndTime = 'end_time';
const String kActionAttrDescription = 'description';

/// KGQL relationship name for umbrella parent → child (`RelationshipType.relation_name`).
const String kActionRelationName = 'action_action';

/// Struct nesting key for the `Action → Action` relation from [buildKgqlStructFromSchema].
const String kActionRelationKey = 'Action';
