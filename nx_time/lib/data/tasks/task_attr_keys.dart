/// KGQL / attribute keys for Task rows — only the data layer imports these.
library;

const String kTaskModelTypeName = 'Task';

const String kTaskAttrStatus = 'status';
/// JSON array of strings; not named `tags` (reserved for KGQL tag assignments on [Model]).
const String kTaskAttrTags = 'task_tags';
const String kTaskAttrDate = 'date';
const String kTaskAttrStartTime = 'start_time';
const String kTaskAttrEndTime = 'end_time';

/// `RelationshipType.relation_name` for parent task → subtask.
const String kTaskRelationName = 'has_subtask';

/// Struct nesting key for `Task → Task` from [buildKgqlStructFromSchema].
const String kTaskRelationKey = 'Task';

/// Task belongs to project.
const String kTaskInProjectRelationName = 'in_project';

/// Generic Task -> Action relation for linking to concrete Action subtype rows.
const String kTaskLinkedActivityRelationName = 'link_to_action';
