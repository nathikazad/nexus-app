import 'package:nx_db/nx_db.dart';

import 'package:nx_time/data/action/action_kgql_struct.dart';

/// Cached [ModelType] for abstract [Action] (from [getKgqlModelType]).
final actionSchemaProvider = modelTypeByNameProvider(kActionModelTypeName);
