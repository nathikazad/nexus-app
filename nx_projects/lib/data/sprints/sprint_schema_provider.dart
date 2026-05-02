import 'package:nx_db/riverpod.dart';

import 'package:nx_projects/data/sprints/sprint_attr_keys.dart';

final sprintSchemaProvider = kgqlModelTypeForPersonalDomain(
  kSprintModelTypeName,
);
