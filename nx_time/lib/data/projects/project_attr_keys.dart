/// KGQL / keys for Project rows — only the data layer imports these.
library;

const String kProjectModelTypeName = 'Project';

/// `RelationshipType.relation_name` for parent project → subproject.
const String kProjectRelationName = 'has_subproject';

/// Struct nesting key for `Project → Project`.
const String kProjectRelationKey = 'Project';
