/// KGQL keys for [Project] rows.
library;

const String kProjectModelTypeName = 'Project';

const String kProjectAttrColor = 'color';

/// `RelationshipType.relation_name` for parent project to subproject.
const String kProjectRelationName = 'has_subproject';

/// Struct nesting key for `Project -> Project` (see `get_kgql_models` nested rows).
const String kProjectRelationKey = 'Project';
