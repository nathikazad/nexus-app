import 'package:nx_db/riverpod.dart';

import 'package:nx_time/data/tasks/task_attr_keys.dart';

/// Cached [ModelType] for [Task] (from [getKgqlModelType]).
final taskSchemaProvider = modelTypeByNameProvider(kTaskModelTypeName);
