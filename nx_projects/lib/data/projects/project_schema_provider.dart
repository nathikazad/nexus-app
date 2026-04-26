import 'package:nx_db/riverpod.dart';

import 'package:nx_projects/data/projects/project_attr_keys.dart';

/// Cached [ModelType] for [Project].
final projectSchemaProvider = modelTypeByNameProvider(kProjectModelTypeName);
