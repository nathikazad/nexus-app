import 'package:nx_db/riverpod.dart';

import 'package:nx_projects/data/tasks/task_attr_keys.dart';

/// [ProjectTask] base schema (optional plain tasks; re-fetch fallback).
final projectTaskSchemaProvider = kgqlModelTypeByNameProvider(
  kTaskBaseModelTypeName,
);

/// [Bug] subtype — includes `severity` and other Bug-only attributes in KGQL struct resolution.
final bugTaskSchemaProvider = kgqlModelTypeByNameProvider(kBugModelTypeName);

/// [Feature] subtype — primary list fetch for feature-shaped tasks.
final featureTaskSchemaProvider = kgqlModelTypeByNameProvider(
  kFeatureModelTypeName,
);
